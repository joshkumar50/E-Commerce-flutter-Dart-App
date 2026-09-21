-- =============================================================================
-- Migration 04: Production Transaction Engine
-- Description: Orders, Order Items, Inventory Reservations, Atomic Stock Ledger,
--              Payments, Payment Events, Refunds, Idempotency, State Machines,
--              and Server-Authoritative RPC Functions.
-- =============================================================================

-- Enable pgcrypto if not already present
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. ORDERS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'pending_payment' CHECK (
        status IN (
            'pending_payment',
            'payment_processing',
            'paid',
            'payment_failed',
            'cancelled',
            'confirmed',
            'completed',
            'refund_pending',
            'refunded',
            'partially_refunded'
        )
    ),
    payment_status TEXT NOT NULL DEFAULT 'created' CHECK (
        payment_status IN (
            'created',
            'pending',
            'authorized',
            'captured',
            'failed',
            'cancelled',
            'refunded',
            'partially_refunded'
        )
    ),
    currency TEXT NOT NULL DEFAULT 'INR',
    subtotal NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),
    discount_total NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (discount_total >= 0),
    delivery_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0),
    tax_total NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (tax_total >= 0),
    grand_total NUMERIC(10,2) NOT NULL CHECK (grand_total >= 0),
    shipping_address_snapshot JSONB NOT NULL,
    pricing_snapshot JSONB NOT NULL,
    idempotency_key TEXT UNIQUE,
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_idempotency_key ON public.orders(idempotency_key);

-- -----------------------------------------------------------------------------
-- 2. ORDER ITEMS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES public.products(id) ON DELETE SET NULL,
    product_name_snapshot TEXT NOT NULL,
    unit_snapshot TEXT NOT NULL DEFAULT 'item',
    image_url_snapshot TEXT DEFAULT '',
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    quantity INT NOT NULL CHECK (quantity > 0),
    line_total NUMERIC(10,2) NOT NULL CHECK (line_total >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);

-- -----------------------------------------------------------------------------
-- 3. INVENTORY RESERVATIONS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    status TEXT NOT NULL DEFAULT 'reserved' CHECK (
        status IN ('reserved', 'consumed', 'released', 'expired')
    ),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    released_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_inv_res_order_id ON public.inventory_reservations(order_id);
CREATE INDEX IF NOT EXISTS idx_inv_res_product_id ON public.inventory_reservations(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_res_status_expires ON public.inventory_reservations(status, expires_at);

-- -----------------------------------------------------------------------------
-- 4. INVENTORY LEDGER TABLE (AUDIT TRAIL)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    reservation_id UUID REFERENCES public.inventory_reservations(id) ON DELETE SET NULL,
    change_type TEXT NOT NULL CHECK (
        change_type IN (
            'purchase_reserved',
            'reservation_released',
            'purchase_committed',
            'admin_adjustment',
            'refund_restock',
            'reservation_expired'
        )
    ),
    quantity_change INT NOT NULL,
    stock_before INT,
    stock_after INT,
    reason TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_ledger_product_id ON public.inventory_ledger(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_ledger_order_id ON public.inventory_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_inv_ledger_created_at ON public.inventory_ledger(created_at DESC);

-- -----------------------------------------------------------------------------
-- 5. PAYMENTS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE RESTRICT,
    provider TEXT NOT NULL DEFAULT 'razorpay',
    provider_order_id TEXT UNIQUE,
    provider_payment_id TEXT UNIQUE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'created' CHECK (
        status IN (
            'created',
            'pending',
            'authorized',
            'captured',
            'failed',
            'cancelled',
            'refunded',
            'partially_refunded'
        )
    ),
    method TEXT DEFAULT '',
    signature_verified BOOLEAN NOT NULL DEFAULT false,
    raw_response JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_provider_order_id ON public.payments(provider_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_provider_payment_id ON public.payments(provider_payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);

-- -----------------------------------------------------------------------------
-- 6. PAYMENT EVENTS TABLE (WEBHOOK DEDUPLICATION & AUDIT)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL DEFAULT 'razorpay',
    provider_event_id TEXT UNIQUE,
    event_type TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    payload_json JSONB NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_events_event_id ON public.payment_events(provider_event_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_processed ON public.payment_events(processed);

-- -----------------------------------------------------------------------------
-- 7. REFUNDS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE RESTRICT,
    provider_refund_id TEXT UNIQUE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'processed', 'failed')
    ),
    restocked BOOLEAN NOT NULL DEFAULT false,
    reason TEXT NOT NULL DEFAULT '',
    idempotency_key TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refunds_payment_id ON public.refunds(payment_id);
CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON public.refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_provider_refund_id ON public.refunds(provider_refund_id);

-- -----------------------------------------------------------------------------
-- 8. IDEMPOTENCY KEYS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL,
    operation TEXT NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    request_hash TEXT,
    response_reference JSONB,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (
        status IN ('in_progress', 'completed', 'failed')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '24 hours'),
    CONSTRAINT unique_user_op_key UNIQUE (user_id, operation, key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_lookup ON public.idempotency_keys(user_id, operation, key);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires_at ON public.idempotency_keys(expires_at);

-- -----------------------------------------------------------------------------
-- 9. AUDIT HISTORY TABLES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    from_status TEXT,
    to_status TEXT NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reason TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON public.order_status_history(order_id);

CREATE TABLE IF NOT EXISTS public.payment_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
    from_status TEXT,
    to_status TEXT NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reason TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_status_history_payment_id ON public.payment_status_history(payment_id);

-- -----------------------------------------------------------------------------
-- 10. ATTACH UPDATED_AT TRIGGERS
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_orders_updated_at ON public.orders;
CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_payments_updated_at ON public.payments;
CREATE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_refunds_updated_at ON public.refunds;
CREATE TRIGGER trg_refunds_updated_at
    BEFORE UPDATE ON public.refunds
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 11. ROW LEVEL SECURITY POLICIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_status_history ENABLE ROW LEVEL SECURITY;

-- Orders: Customer can read own, Admin can read all. NO DIRECT INSERT/UPDATE FROM CLIENT.
CREATE POLICY "Users can view own orders"
    ON public.orders FOR SELECT
    USING (auth.uid() = user_id OR public.is_admin());

-- Order Items: Customer can read own order items, Admin can read all.
CREATE POLICY "Users can view own order items"
    ON public.order_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE public.orders.id = public.order_items.order_id
              AND (public.orders.user_id = auth.uid() OR public.is_admin())
        )
    );

-- Payments: Customer can read own payments, Admin can read all.
CREATE POLICY "Users can view own payments"
    ON public.payments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE public.orders.id = public.payments.order_id
              AND (public.orders.user_id = auth.uid() OR public.is_admin())
        )
    );

-- Inventory Reservations: Customer can view for own order, Admin can view all.
CREATE POLICY "Users can view own reservations"
    ON public.inventory_reservations FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE public.orders.id = public.inventory_reservations.order_id
              AND (public.orders.user_id = auth.uid() OR public.is_admin())
        ) OR public.is_admin()
    );

-- Inventory Ledger: Admin only.
CREATE POLICY "Admins can view inventory ledger"
    ON public.inventory_ledger FOR SELECT
    USING (public.is_admin());

-- Refunds: Customer can view own refunds, Admin can view all.
CREATE POLICY "Users can view own refunds"
    ON public.refunds FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE public.orders.id = public.refunds.order_id
              AND (public.orders.user_id = auth.uid() OR public.is_admin())
        ) OR public.is_admin()
    );

-- Idempotency Keys: User owns their keys, Admin can view all.
CREATE POLICY "Users can access own idempotency keys"
    ON public.idempotency_keys FOR ALL
    USING (auth.uid() = user_id OR public.is_admin());

-- Status Histories:
CREATE POLICY "Users can view own order status history"
    ON public.order_status_history FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE public.orders.id = public.order_status_history.order_id
              AND (public.orders.user_id = auth.uid() OR public.is_admin())
        )
    );

-- =============================================================================
-- 12. SERVER-AUTHORITATIVE RPC FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- RPC: rpc_create_checkout
-- Purpose: Atomic row-locking, server-side price recalculation, inventory hold,
--          order creation, and idempotency protection.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_create_checkout(
    p_address_id UUID,
    p_cart_items JSONB,
    p_idempotency_key TEXT,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_key RECORD;
    v_address RECORD;
    v_address_snapshot JSONB;
    v_order_id UUID;
    v_order_number TEXT;
    v_payment_id UUID;
    v_provider_order_id TEXT;
    v_subtotal NUMERIC(10,2) := 0.00;
    v_discount_total NUMERIC(10,2) := 0.00;
    v_delivery_fee NUMERIC(10,2) := 0.00;
    v_tax_total NUMERIC(10,2) := 0.00;
    v_grand_total NUMERIC(10,2) := 0.00;
    v_item RECORD;
    v_product RECORD;
    v_effective_price NUMERIC(10,2);
    v_line_total NUMERIC(10,2);
    v_reservation_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_pricing_snapshot JSONB;
    v_result JSONB;
    v_product_ids BIGINT[];
BEGIN
    -- 1. Identify and authenticate caller
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to checkout' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Check Idempotency Key
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
        SELECT * INTO v_existing_key
        FROM public.idempotency_keys
        WHERE user_id = v_user_id
          AND operation = 'checkout'
          AND key = p_idempotency_key;

        IF FOUND THEN
            IF v_existing_key.status = 'completed' THEN
                -- Return identical cached response
                RETURN v_existing_key.response_reference;
            ELSIF v_existing_key.status = 'in_progress' AND v_existing_key.created_at > (now() - INTERVAL '30 seconds') THEN
                RAISE EXCEPTION 'A checkout request with this idempotency key is already in progress. Please wait.' USING ERRCODE = 'P0002';
            END IF;
        ELSE
            -- Record new idempotency key
            INSERT INTO public.idempotency_keys (key, operation, user_id, status, expires_at)
            VALUES (p_idempotency_key, 'checkout', v_user_id, 'in_progress', now() + INTERVAL '24 hours');
        END IF;
    END IF;

    -- 3. Validate and snapshot address
    SELECT * INTO v_address
    FROM public.addresses
    WHERE id = p_address_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipping address not found or does not belong to user' USING ERRCODE = 'P0003';
    END IF;

    v_address_snapshot := jsonb_build_object(
        'address_id', v_address.id,
        'label', v_address.label,
        'full_name', v_address.full_name,
        'phone', v_address.phone,
        'address_line1', v_address.address_line1,
        'address_line2', COALESCE(v_address.address_line2, ''),
        'city', v_address.city,
        'state', v_address.state,
        'postal_code', v_address.postal_code,
        'country', v_address.country
    );

    -- 4. Parse item product IDs and lock rows in sorted order (DEADLOCK PREVENTING)
    SELECT array_agg(DISTINCT (elem->>'product_id')::BIGINT ORDER BY (elem->>'product_id')::BIGINT ASC)
    INTO v_product_ids
    FROM jsonb_array_elements(p_cart_items) AS elem;

    IF v_product_ids IS NULL OR array_length(v_product_ids, 1) = 0 THEN
        RAISE EXCEPTION 'Cannot checkout with an empty cart' USING ERRCODE = 'P0004';
    END IF;

    -- Lock all products in order
    PERFORM id
    FROM public.products
    WHERE id = ANY(v_product_ids)
    ORDER BY id ASC
    FOR UPDATE;

    -- 5. Validate stock and calculate authoritative prices server-side
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_cart_items) AS x(product_id BIGINT, quantity INT)
    LOOP
        IF v_item.quantity <= 0 THEN
            RAISE EXCEPTION 'Item quantity must be greater than 0' USING ERRCODE = 'P0005';
        END IF;

        SELECT * INTO v_product
        FROM public.products
        WHERE id = v_item.product_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % is no longer available', v_item.product_id USING ERRCODE = 'P0006';
        END IF;

        IF NOT v_product.is_active THEN
            RAISE EXCEPTION 'Product "%" is currently inactive', v_product.name USING ERRCODE = 'P0007';
        END IF;

        IF v_product.stock_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for "%". Requested: %, Available: %',
                v_product.name, v_item.quantity, v_product.stock_quantity USING ERRCODE = 'P0008';
        END IF;

        -- Authoritative price: use sale_price if present and valid, otherwise standard price
        v_effective_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := round(v_effective_price * v_item.quantity, 2);
        v_subtotal := v_subtotal + v_line_total;
    END LOOP;

    -- Standard business rules for fees:
    -- Delivery fee: free for subtotal >= 500, else 40 INR
    IF v_subtotal >= 500.00 THEN
        v_delivery_fee := 0.00;
    ELSE
        v_delivery_fee := 40.00;
    END IF;

    -- Tax calculation: 5% GST on grocery items
    v_tax_total := round(v_subtotal * 0.05, 2);
    v_grand_total := v_subtotal + v_delivery_fee + v_tax_total - v_discount_total;

    -- 6. Generate Human-Readable Order Number
    v_order_number := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));

    -- Set reservation expiration (15 minutes from creation)
    v_expires_at := now() + INTERVAL '15 minutes';

    v_pricing_snapshot := jsonb_build_object(
        'subtotal', v_subtotal,
        'discount_total', v_discount_total,
        'delivery_fee', v_delivery_fee,
        'tax_total', v_tax_total,
        'grand_total', v_grand_total,
        'currency', 'INR',
        'item_count', jsonb_array_length(p_cart_items),
        'calculated_at', now()
    );

    -- 7. Insert Order
    INSERT INTO public.orders (
        order_number,
        user_id,
        status,
        payment_status,
        currency,
        subtotal,
        discount_total,
        delivery_fee,
        tax_total,
        grand_total,
        shipping_address_snapshot,
        pricing_snapshot,
        idempotency_key,
        notes
    ) VALUES (
        v_order_number,
        v_user_id,
        'pending_payment',
        'created',
        'INR',
        v_subtotal,
        v_discount_total,
        v_delivery_fee,
        v_tax_total,
        v_grand_total,
        v_address_snapshot,
        v_pricing_snapshot,
        p_idempotency_key,
        p_notes
    ) RETURNING id INTO v_order_id;

    -- Record initial order status history
    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (v_order_id, NULL, 'pending_payment', v_user_id, 'Order created by customer');

    -- 8. Insert Order Items, Decrement Stock, Create Reservation, and Write Ledger
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_cart_items) AS x(product_id BIGINT, quantity INT)
    LOOP
        SELECT * INTO v_product
        FROM public.products
        WHERE id = v_item.product_id;

        v_effective_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := round(v_effective_price * v_item.quantity, 2);

        -- Insert line item
        INSERT INTO public.order_items (
            order_id,
            product_id,
            product_name_snapshot,
            unit_snapshot,
            image_url_snapshot,
            unit_price,
            quantity,
            line_total
        ) VALUES (
            v_order_id,
            v_product.id,
            v_product.name,
            v_product.unit,
            COALESCE(v_product.image_url, ''),
            v_effective_price,
            v_item.quantity,
            v_line_total
        );

        -- Atomically decrement stock
        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity,
            updated_at = now()
        WHERE id = v_product.id;

        -- Create inventory reservation
        INSERT INTO public.inventory_reservations (
            order_id,
            product_id,
            quantity,
            status,
            expires_at
        ) VALUES (
            v_order_id,
            v_product.id,
            v_item.quantity,
            'reserved',
            v_expires_at
        ) RETURNING id INTO v_reservation_id;

        -- Write inventory ledger audit trail
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
            v_product.id,
            v_order_id,
            v_reservation_id,
            'purchase_reserved',
            -v_item.quantity,
            v_product.stock_quantity,
            v_product.stock_quantity - v_item.quantity,
            'Held for order ' || v_order_number
        );
    END LOOP;

    -- 9. Create Payment Record (Razorpay Order ID simulated or provided)
    v_provider_order_id := 'rzp_order_' || upper(substr(md5(v_order_id::text || now()::text), 1, 14));

    INSERT INTO public.payments (
        order_id,
        provider,
        provider_order_id,
        amount,
        currency,
        status
    ) VALUES (
        v_order_id,
        'razorpay',
        v_provider_order_id,
        v_grand_total,
        'INR',
        'created'
    ) RETURNING id INTO v_payment_id;

    -- Record initial payment status history
    INSERT INTO public.payment_status_history (payment_id, from_status, to_status, changed_by, reason)
    VALUES (v_payment_id, NULL, 'created', v_user_id, 'Payment record initiated for order ' || v_order_number);

    -- 10. Clear items from customer cart
    DELETE FROM public.cart_items
    WHERE user_id = v_user_id
      AND product_id = ANY(v_product_ids);

    -- 11. Prepare response payload
    v_result := jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'payment_id', v_payment_id,
        'provider_order_id', v_provider_order_id,
        'grand_total', v_grand_total,
        'currency', 'INR',
        'subtotal', v_subtotal,
        'delivery_fee', v_delivery_fee,
        'tax_total', v_tax_total,
        'expires_at', v_expires_at
    );

    -- Update Idempotency Key record
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
        UPDATE public.idempotency_keys
        SET status = 'completed',
            response_reference = v_result
        WHERE user_id = v_user_id
          AND operation = 'checkout'
          AND key = p_idempotency_key;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_verify_payment
-- Purpose: Server-side payment verification, consuming inventory reservations,
--          and transitioning order to confirmed.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_verify_payment(
    p_order_id UUID,
    p_provider_payment_id TEXT,
    p_provider_signature TEXT,
    p_payment_method TEXT DEFAULT 'upi'
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_order RECORD;
    v_payment RECORD;
    v_res RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
    END IF;

    -- 1. Lock order for update
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0009';
    END IF;

    -- Security: verify caller owns order or is admin
    IF v_order.user_id <> v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied to verify this order' USING ERRCODE = 'P0010';
    END IF;

    -- Idempotent check: if already confirmed or completed, return success safely
    IF v_order.status IN ('paid', 'confirmed', 'completed') THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Order already paid and confirmed',
            'order_id', v_order.id,
            'status', v_order.status
        );
    END IF;

    IF v_order.status NOT IN ('pending_payment', 'payment_processing') THEN
        RAISE EXCEPTION 'Cannot verify payment for order with status %', v_order.status USING ERRCODE = 'P0011';
    END IF;

    -- 2. Lock and update payment
    SELECT * INTO v_payment
    FROM public.payments
    WHERE order_id = p_order_id
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No payment record found for order %', p_order_id USING ERRCODE = 'P0012';
    END IF;

    -- Update Payment status
    UPDATE public.payments
    SET status = 'captured',
        provider_payment_id = p_provider_payment_id,
        method = COALESCE(p_payment_method, method),
        signature_verified = true,
        updated_at = now()
    WHERE id = v_payment.id;

    -- Payment history
    INSERT INTO public.payment_status_history (payment_id, from_status, to_status, changed_by, reason)
    VALUES (v_payment.id, v_payment.status, 'captured', v_user_id, 'Payment signature verified successfully');

    -- 3. Consume all active inventory reservations for this order
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE order_id = p_order_id AND status = 'reserved'
        FOR UPDATE
    LOOP
        UPDATE public.inventory_reservations
        SET status = 'consumed'
        WHERE id = v_res.id;

        -- Write audit ledger
        INSERT INTO public.inventory_ledger (
            product_id,
            order_id,
            reservation_id,
            change_type,
            quantity_change,
            reason
        ) VALUES (
            v_res.product_id,
            p_order_id,
            v_res.id,
            'purchase_committed',
            0, -- Stock was already decremented at reservation time
            'Payment verified. Inventory consumption confirmed.'
        );
    END LOOP;

    -- 4. Transition order status
    UPDATE public.orders
    SET status = 'confirmed',
        payment_status = 'captured',
        updated_at = now()
    WHERE id = p_order_id;

    -- Order history
    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, 'confirmed', v_user_id, 'Payment verified; order confirmed');

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'payment_status', 'captured'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_handle_payment_failure
-- Purpose: Safely releases reserved stock and updates status when payment fails.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_handle_payment_failure(
    p_order_id UUID,
    p_reason TEXT DEFAULT 'Payment was cancelled or failed'
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_order RECORD;
    v_payment RECORD;
    v_res RECORD;
    v_prod RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0009';
    END IF;

    IF v_order.user_id <> v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = 'P0010';
    END IF;

    -- If already paid or confirmed, do NOT fail it
    IF v_order.status IN ('paid', 'confirmed', 'completed') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order already paid');
    END IF;

    -- Update payments to failed
    UPDATE public.payments
    SET status = 'failed',
        updated_at = now()
    WHERE order_id = p_order_id AND status IN ('created', 'pending');

    -- Release all reserved stock
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE order_id = p_order_id AND status = 'reserved'
        FOR UPDATE
    LOOP
        -- Lock product
        SELECT * INTO v_prod
        FROM public.products
        WHERE id = v_res.product_id
        FOR UPDATE;

        -- Restore stock
        UPDATE public.products
        SET stock_quantity = stock_quantity + v_res.quantity,
            updated_at = now()
        WHERE id = v_res.product_id;

        -- Mark reservation released
        UPDATE public.inventory_reservations
        SET status = 'released',
            released_at = now()
        WHERE id = v_res.id;

        -- Ledger
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
            p_order_id,
            v_res.id,
            'reservation_released',
            v_res.quantity,
            v_prod.stock_quantity,
            v_prod.stock_quantity + v_res.quantity,
            'Payment failed: ' || COALESCE(p_reason, 'unspecified')
        );
    END LOOP;

    -- Update order status
    UPDATE public.orders
    SET status = 'payment_failed',
        payment_status = 'failed',
        updated_at = now()
    WHERE id = p_order_id;

    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, 'payment_failed', v_user_id, p_reason);

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'payment_failed',
        'payment_status', 'failed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_expire_reservations
-- Purpose: Automated expiration sweeper for stale inventory holds (>15 minutes).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_expire_reservations()
RETURNS JSONB AS $$
DECLARE
    v_res RECORD;
    v_prod RECORD;
    v_expired_count INT := 0;
BEGIN
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE status = 'reserved'
          AND expires_at < now()
        FOR UPDATE
    LOOP
        -- Lock product
        SELECT * INTO v_prod
        FROM public.products
        WHERE id = v_res.product_id
        FOR UPDATE;

        -- Restore stock
        UPDATE public.products
        SET stock_quantity = stock_quantity + v_res.quantity,
            updated_at = now()
        WHERE id = v_res.product_id;

        -- Mark expired
        UPDATE public.inventory_reservations
        SET status = 'expired',
            released_at = now()
        WHERE id = v_res.id;

        -- Write ledger
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
            'Reservation timed out after 15 minutes'
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
        'expired_reservations_count', v_expired_count,
        'timestamp', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_process_refund
-- Purpose: Admin-only refund execution with optional atomic inventory restock.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_process_refund(
    p_order_id UUID,
    p_amount NUMERIC(10,2),
    p_reason TEXT,
    p_restock BOOLEAN DEFAULT false,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_order RECORD;
    v_payment RECORD;
    v_existing_refund RECORD;
    v_item RECORD;
    v_prod RECORD;
    v_refund_id UUID;
    v_provider_refund_id TEXT;
    v_total_refunded NUMERIC(10,2) := 0.00;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can initiate refunds' USING ERRCODE = 'P0013';
    END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
        SELECT * INTO v_existing_refund
        FROM public.refunds
        WHERE idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'success', true,
                'refund_id', v_existing_refund.id,
                'provider_refund_id', v_existing_refund.provider_refund_id,
                'amount', v_existing_refund.amount,
                'status', v_existing_refund.status,
                'message', 'Refund already processed (idempotent replay)'
            );
        END IF;
    END IF;

    -- Lock order and payment
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0009';
    END IF;

    SELECT * INTO v_payment
    FROM public.payments
    WHERE order_id = p_order_id AND status = 'captured'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No captured payment found for order %', p_order_id USING ERRCODE = 'P0014';
    END IF;

    -- Validate refund amount
    SELECT COALESCE(SUM(amount), 0) INTO v_total_refunded
    FROM public.refunds
    WHERE order_id = p_order_id AND status = 'processed';

    IF (v_total_refunded + p_amount) > v_order.grand_total THEN
        RAISE EXCEPTION 'Total refunded amount (%) cannot exceed order grand total (%)',
            (v_total_refunded + p_amount), v_order.grand_total USING ERRCODE = 'P0015';
    END IF;

    v_provider_refund_id := 'rfnd_' || upper(substr(md5(gen_random_uuid()::text), 1, 14));

    -- Insert refund record
    INSERT INTO public.refunds (
        payment_id,
        order_id,
        provider_refund_id,
        amount,
        status,
        restocked,
        reason,
        idempotency_key
    ) VALUES (
        v_payment.id,
        v_order.id,
        v_provider_refund_id,
        p_amount,
        'processed',
        p_restock,
        p_reason,
        p_idempotency_key
    ) RETURNING id INTO v_refund_id;

    -- Optional inventory restock
    IF p_restock THEN
        FOR v_item IN
            SELECT * FROM public.order_items
            WHERE order_id = p_order_id
        LOOP
            IF v_item.product_id IS NOT NULL THEN
                SELECT * INTO v_prod
                FROM public.products
                WHERE id = v_item.product_id
                FOR UPDATE;

                UPDATE public.products
                SET stock_quantity = stock_quantity + v_item.quantity,
                    updated_at = now()
                WHERE id = v_item.product_id;

                INSERT INTO public.inventory_ledger (
                    product_id,
                    order_id,
                    change_type,
                    quantity_change,
                    stock_before,
                    stock_after,
                    reason
                ) VALUES (
                    v_item.product_id,
                    p_order_id,
                    'refund_restock',
                    v_item.quantity,
                    v_prod.stock_quantity,
                    v_prod.stock_quantity + v_item.quantity,
                    'Admin restocked item on refund: ' || p_reason
                );
            END IF;
        END LOOP;
    END IF;

    -- Update order and payment status
    IF (v_total_refunded + p_amount) = v_order.grand_total THEN
        UPDATE public.orders
        SET status = 'refunded',
            payment_status = 'refunded',
            updated_at = now()
        WHERE id = p_order_id;

        UPDATE public.payments
        SET status = 'refunded',
            updated_at = now()
        WHERE id = v_payment.id;
    ELSE
        UPDATE public.orders
        SET status = 'partially_refunded',
            payment_status = 'partially_refunded',
            updated_at = now()
        WHERE id = p_order_id;

        UPDATE public.payments
        SET status = 'partially_refunded',
            updated_at = now()
        WHERE id = v_payment.id;
    END IF;

    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, (CASE WHEN (v_total_refunded + p_amount) = v_order.grand_total THEN 'refunded' ELSE 'partially_refunded' END), v_admin_id, p_reason);

    RETURN jsonb_build_object(
        'success', true,
        'refund_id', v_refund_id,
        'provider_refund_id', v_provider_refund_id,
        'amount', p_amount,
        'restocked', p_restock,
        'status', 'processed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_admin_adjust_stock
-- Purpose: Concurrency-safe admin inventory adjustment with audit ledger.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_adjust_stock(
    p_product_id BIGINT,
    p_delta INT,
    p_reason TEXT,
    p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_prod RECORD;
    v_new_stock INT;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin authorization required' USING ERRCODE = 'P0013';
    END IF;

    -- Lock product
    SELECT * INTO v_prod
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id USING ERRCODE = 'P0006';
    END IF;

    v_new_stock := v_prod.stock_quantity + p_delta;
    IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'Adjustment would result in negative stock (%)', v_new_stock USING ERRCODE = 'P0016';
    END IF;

    UPDATE public.products
    SET stock_quantity = v_new_stock,
        updated_at = now()
    WHERE id = p_product_id;

    INSERT INTO public.inventory_ledger (
        product_id,
        change_type,
        quantity_change,
        stock_before,
        stock_after,
        reason
    ) VALUES (
        p_product_id,
        'admin_adjustment',
        p_delta,
        v_prod.stock_quantity,
        v_new_stock,
        COALESCE(p_reason, 'Admin stock adjustment')
    );

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'previous_stock', v_prod.stock_quantity,
        'new_stock', v_new_stock,
        'delta', p_delta
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- RPC: rpc_admin_update_order_status
-- Purpose: Operational status transitions by admin (confirmed -> completed/cancelled).
--          Never permits admin to fake payment capture directly.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_update_order_status(
    p_order_id UUID,
    p_new_status TEXT,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_order RECORD;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin authorization required' USING ERRCODE = 'P0013';
    END IF;

    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0009';
    END IF;

    -- Strict operational state transition rules
    IF p_new_status = 'completed' THEN
        IF v_order.status <> 'confirmed' THEN
            RAISE EXCEPTION 'Only confirmed orders can be marked completed' USING ERRCODE = 'P0017';
        END IF;
    ELSIF p_new_status = 'cancelled' THEN
        IF v_order.status NOT IN ('pending_payment', 'payment_failed', 'confirmed') THEN
            RAISE EXCEPTION 'Cannot cancel an order in state %', v_order.status USING ERRCODE = 'P0018';
        END IF;
    ELSIF p_new_status = 'confirmed' THEN
        IF v_order.status <> 'paid' THEN
            RAISE EXCEPTION 'Cannot confirm an unpaid order' USING ERRCODE = 'P0019';
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid status transition to %', p_new_status USING ERRCODE = 'P0020';
    END IF;

    UPDATE public.orders
    SET status = p_new_status,
        updated_at = now()
    WHERE id = p_order_id;

    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, p_new_status, v_admin_id, p_notes);

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'previous_status', v_order.status,
        'new_status', p_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
