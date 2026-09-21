-- =============================================================================
-- Migration: 20260921000005_scalability_and_performance.sql
-- Description: Phase 6 Production Scalability, High Traffic Indexing,
--              PostgreSQL Trigram Search, STABLE RLS optimizations,
--              Atomic Cart Upsert RPC, Paginated Catalog RPC, and
--              Bounded Reservation Expiration Sweeper.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. POSTGRESQL EXTENSIONS
-- -----------------------------------------------------------------------------
-- Enable trigram extension for accelerated substring and fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- -----------------------------------------------------------------------------
-- 2. HIGH-CONCURRENCY INDEXING STRATEGY
-- -----------------------------------------------------------------------------

-- Accelerated substring search on products using GIN Trigram
CREATE INDEX IF NOT EXISTS idx_products_name_trgm 
    ON public.products USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_products_search_trgm 
    ON public.products USING gin ((name || ' ' || COALESCE(description, '')) gin_trgm_ops);

-- Composite index for fast category filtering on active catalog
CREATE INDEX IF NOT EXISTS idx_products_active_category_id 
    ON public.products (is_active, category_id, id);

-- Composite indexes for customer and admin order queries
CREATE INDEX IF NOT EXISTS idx_orders_user_created_desc 
    ON public.orders (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_created_desc 
    ON public.orders (status, created_at DESC);

-- Fast join resolution for order details and item snapshots
CREATE INDEX IF NOT EXISTS idx_order_items_order_id 
    ON public.order_items (order_id);

-- Partial index for active inventory reservation expiration sweeper
CREATE INDEX IF NOT EXISTS idx_inv_res_status_expires 
    ON public.inventory_reservations (status, expires_at) 
    WHERE status = 'reserved';

-- Payment lookup optimization by order and provider ID
CREATE INDEX IF NOT EXISTS idx_payments_order_status 
    ON public.payments (order_id, status);

CREATE INDEX IF NOT EXISTS idx_payments_provider_id 
    ON public.payments (provider_payment_id);

-- Enforce uniqueness on (user_id, product_id) for atomic cart operations
CREATE UNIQUE INDEX IF NOT EXISTS idx_cart_items_user_product 
    ON public.cart_items (user_id, product_id);

-- Fast lookup for customer addresses
CREATE INDEX IF NOT EXISTS idx_addresses_user_is_default 
    ON public.addresses (user_id, is_default);

-- Fast lookup for wishlist favorites
CREATE INDEX IF NOT EXISTS idx_wishlist_user_product 
    ON public.wishlist_items (user_id, product_id);

-- -----------------------------------------------------------------------------
-- 3. RLS PERFORMANCE OPTIMIZATION (STABLE FUNCTION)
-- Marking is_admin() as STABLE allows PostgreSQL to evaluate it once per
-- statement/transaction rather than re-evaluating the subquery for every single row.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. ATOMIC CART UPSERT RPC
-- Eliminates client-side 2-step SELECT + INSERT/UPDATE race conditions.
-- Reduces network round-trips by 50%.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_upsert_cart_item(
    p_product_id INT,
    p_quantity INT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to modify cart';
    END IF;

    IF p_quantity <= 0 THEN
        DELETE FROM public.cart_items
        WHERE user_id = v_user_id AND product_id = p_product_id;
        RETURN jsonb_build_object('success', true, 'action', 'deleted');
    END IF;

    -- Atomic upsert using ON CONFLICT (user_id, product_id)
    INSERT INTO public.cart_items (user_id, product_id, quantity, updated_at)
    VALUES (v_user_id, p_product_id, p_quantity, now())
    ON CONFLICT (user_id, product_id)
    DO UPDATE SET
        quantity = cart_items.quantity + EXCLUDED.quantity,
        updated_at = now()
    RETURNING * INTO v_item;

    RETURN jsonb_build_object(
        'success', true,
        'action', 'upserted',
        'id', v_item.id,
        'product_id', v_item.product_id,
        'quantity', v_item.quantity
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. BOUNDED PAGINATED PRODUCT CATALOG RPC
-- Prevents unbounded memory consumption and network egress.
-- Bounded limit (max 100 rows per query).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_fetch_products_paginated(
    p_category_id TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_active_only BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    id INT,
    name TEXT,
    description TEXT,
    price NUMERIC,
    unit TEXT,
    image_url TEXT,
    category_id TEXT,
    stock_quantity INT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
DECLARE
    v_safe_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
    v_safe_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_search_clean TEXT := NULLIF(TRIM(p_search), '');
BEGIN
    RETURN QUERY
    WITH filtered AS (
        SELECT p.*
        FROM public.products p
        WHERE (NOT p_active_only OR p.is_active = true)
          AND (p_category_id IS NULL OR p.category_id = p_category_id)
          AND (v_search_clean IS NULL OR p.name ILIKE '%' || v_search_clean || '%' OR p.description ILIKE '%' || v_search_clean || '%')
    ),
    counted AS (
        SELECT COUNT(*) AS cnt FROM filtered
    )
    SELECT
        f.id,
        f.name,
        f.description,
        f.price,
        f.unit,
        f.image_url,
        f.category_id,
        f.stock_quantity,
        f.is_active,
        f.created_at,
        f.updated_at,
        c.cnt AS total_count
    FROM filtered f
    CROSS JOIN counted c
    ORDER BY f.id ASC
    LIMIT v_safe_limit
    OFFSET v_safe_offset;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. SCALABLE BOUNDED RESERVATION EXPIRATION SWEEPER
-- Replaces unbounded cursor scan with bounded batching (LIMIT 50) and
-- SKIP LOCKED to allow concurrent background workers without blocking.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_expire_reservations(p_batch_size INT DEFAULT 50)
RETURNS JSONB AS $$
DECLARE
    v_res RECORD;
    v_prod RECORD;
    v_expired_count INT := 0;
    v_safe_batch INT := LEAST(GREATEST(COALESCE(p_batch_size, 50), 1), 100);
BEGIN
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE status = 'reserved'
          AND expires_at < now()
        ORDER BY expires_at ASC
        LIMIT v_safe_batch
        FOR UPDATE SKIP LOCKED
    LOOP
        -- Lock product deterministically
        SELECT * INTO v_prod
        FROM public.products
        WHERE id = v_res.product_id
        FOR UPDATE;

        -- Restore inventory stock
        UPDATE public.products
        SET stock_quantity = stock_quantity + v_res.quantity,
            updated_at = now()
        WHERE id = v_res.product_id;

        -- Mark reservation expired
        UPDATE public.inventory_reservations
        SET status = 'expired',
            released_at = now()
        WHERE id = v_res.id;

        -- Write audit ledger entry
        INSERT INTO public.inventory_ledger (
            product_id,
            order_id,
            reservation_id,
            change_type,
            quantity_change,
            stock_before,
            stock_after,
            reason
        ) VALUES (
            v_res.product_id,
            v_res.order_id,
            v_res.id,
            'reservation_expired',
            v_res.quantity,
            v_prod.stock_quantity,
            v_prod.stock_quantity + v_res.quantity,
            'Bounded batch expiration: hold exceeded 15 minutes'
        );

        -- Cancel order if still pending
        IF v_res.order_id IS NOT NULL THEN
            UPDATE public.orders
            SET status = 'cancelled',
                updated_at = now()
            WHERE id = v_res.order_id
              AND status IN ('pending_payment', 'payment_processing');
        END IF;

        v_expired_count := v_expired_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'expired_count', v_expired_count,
        'batch_size_applied', v_safe_batch,
        'executed_at', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. GRANT PERMISSIONS
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.rpc_upsert_cart_item(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_fetch_products_paginated(TEXT, TEXT, INT, INT, BOOLEAN) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_expire_reservations(INT) TO authenticated, service_role;
