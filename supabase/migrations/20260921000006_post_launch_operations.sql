-- =============================================================================
-- Migration: 20260921000006_post_launch_operations.sql
-- Description: Phase 8 Post-Launch Operations, Business Funnel Analytics,
--              Immutable Admin Audit Logs, Remote App Config & Feature Flags,
--              Automated Data Health & Reconciliation RPCs, and Bounded Telemetry Retention.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ANALYTICS EVENTS TABLE
-- High-throughput, partition-ready event telemetry table.
-- Captures business funnel events without blocking shopping transactions.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    anonymous_id TEXT,
    session_id TEXT,
    event_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    properties JSONB NOT NULL DEFAULT '{}'::jsonb,
    app_version TEXT,
    platform TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexing for fast funnel aggregation and operational reporting
CREATE INDEX IF NOT EXISTS idx_analytics_events_type_created 
    ON public.analytics_events (event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_created 
    ON public.analytics_events (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_created 
    ON public.analytics_events (created_at DESC);

-- Enable RLS on analytics_events
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Customers & visitors can insert their own events (non-blocking)
CREATE POLICY "Anyone can insert analytics events"
    ON public.analytics_events FOR INSERT
    WITH CHECK (true);

-- Only admins can query analytics events
CREATE POLICY "Admins can view analytics events"
    ON public.analytics_events FOR SELECT
    USING (public.is_admin());

-- Disallow updates and deletes (events are immutable)
CREATE POLICY "No updates on analytics events"
    ON public.analytics_events FOR UPDATE
    USING (false);

CREATE POLICY "Admins can purge expired analytics via maintenance RPC"
    ON public.analytics_events FOR DELETE
    USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 2. ADMIN AUDIT LOGS TABLE
-- Immutable accountability log for all sensitive admin operations
-- (price changes, inventory adjustments, product activation, refunds, flags).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_email TEXT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    reason TEXT,
    severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
    request_id TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexing for audit lookups and timeline inspection
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity 
    ON public.admin_audit_logs (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created 
    ON public.admin_audit_logs (actor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created 
    ON public.admin_audit_logs (action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created 
    ON public.admin_audit_logs (created_at DESC);

-- Enable RLS on admin_audit_logs
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can insert and read audit logs
CREATE POLICY "Admins can read audit logs"
    ON public.admin_audit_logs FOR SELECT
    USING (public.is_admin());

CREATE POLICY "Admins can insert audit logs"
    ON public.admin_audit_logs FOR INSERT
    WITH CHECK (public.is_admin());

-- Audit logs are strictly immutable: no updates or direct deletes allowed
CREATE POLICY "Audit logs cannot be updated"
    ON public.admin_audit_logs FOR UPDATE
    USING (false);

CREATE POLICY "Audit logs cannot be deleted"
    ON public.admin_audit_logs FOR DELETE
    USING (false);

-- -----------------------------------------------------------------------------
-- 3. REMOTE APP CONFIG & FEATURE FLAGS TABLE
-- Server-controlled flags, minimum version gates, and emergency kill switches.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on app_config
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Everyone can read config (needed for mobile app startup check)
CREATE POLICY "Public can view app config"
    ON public.app_config FOR SELECT
    USING (true);

-- Only admins can modify remote config
CREATE POLICY "Admins can manage app config"
    ON public.app_config FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Seed initial default remote configuration
INSERT INTO public.app_config (key, value, description)
VALUES 
    ('min_supported_version', '{"android": "1.0.0", "ios": "1.0.0"}'::jsonb, 'Minimum app version required before update is forced'),
    ('recommended_version', '{"android": "1.0.0", "ios": "1.0.0"}'::jsonb, 'Latest recommended version for soft update prompt'),
    ('maintenance_mode', '{"enabled": false, "message": "We are currently undergoing scheduled maintenance. Please check back shortly."}'::jsonb, 'Global maintenance mode gate for customer application'),
    ('feature_flags', '{"recommendations": true, "new_checkout": true, "enhanced_search": true, "deals_banner": true, "review_system": false}'::jsonb, 'Dynamic feature toggles for controlled rollout'),
    ('kill_switches', '{"disable_checkout": false, "disable_payments": false, "disable_refunds": false, "disable_realtime": false}'::jsonb, 'Emergency server-side kill switches for disaster mitigation')
ON CONFLICT (key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 4. RPC: AUDIT LOGGING HELPER
-- Provides a clean, standardized function for logging admin actions.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_log_admin_audit(
    p_action TEXT,
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_previous_state JSONB DEFAULT NULL,
    p_new_state JSONB DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_severity TEXT DEFAULT 'info',
    p_request_id TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_actor_email TEXT;
    v_log_id BIGINT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can write audit records';
    END IF;

    SELECT email INTO v_actor_email FROM auth.users WHERE id = v_actor_id;

    INSERT INTO public.admin_audit_logs (
        actor_id,
        actor_email,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state,
        reason,
        severity,
        request_id
    ) VALUES (
        v_actor_id,
        v_actor_email,
        p_action,
        p_entity_type,
        p_entity_id,
        p_previous_state,
        p_new_state,
        p_reason,
        COALESCE(p_severity, 'info'),
        p_request_id
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. RPC: AUTOMATED DATA QUALITY HEALTH CHECK
-- Automated inspector for negative stock, invalid pricing, stuck reservations,
-- and orphaned records across transactional tables.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_run_data_health_check()
RETURNS JSONB AS $$
DECLARE
    v_negative_stock INT := 0;
    v_invalid_prices INT := 0;
    v_stuck_reservations INT := 0;
    v_orphaned_order_items INT := 0;
    v_orphaned_payments INT := 0;
    v_unresolved_payments INT := 0;
    v_missing_categories INT := 0;
    v_missing_images INT := 0;
    v_action_count INT := 0;
    v_status TEXT := 'HEALTHY';
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can run data health checks';
    END IF;

    -- Check 1: Negative stock quantities
    SELECT COUNT(*) INTO v_negative_stock 
    FROM public.products 
    WHERE stock_quantity < 0;

    -- Check 2: Invalid prices (zero or negative)
    SELECT COUNT(*) INTO v_invalid_prices 
    FROM public.products 
    WHERE price <= 0;

    -- Check 3: Stuck reservations (reserved status but expired over 15 minutes ago)
    SELECT COUNT(*) INTO v_stuck_reservations 
    FROM public.inventory_reservations 
    WHERE status = 'reserved' AND expires_at < (now() - INTERVAL '15 minutes');

    -- Check 4: Orphaned order items without parent order
    SELECT COUNT(*) INTO v_orphaned_order_items 
    FROM public.order_items oi 
    LEFT JOIN public.orders o ON oi.order_id = o.id 
    WHERE o.id IS NULL;

    -- Check 5: Orphaned payments without parent order
    SELECT COUNT(*) INTO v_orphaned_payments 
    FROM public.payments p 
    LEFT JOIN public.orders o ON p.order_id = o.id 
    WHERE o.id IS NULL;

    -- Check 6: Unresolved payments (pending over 2 hours)
    SELECT COUNT(*) INTO v_unresolved_payments 
    FROM public.payments 
    WHERE status = 'pending' AND created_at < (now() - INTERVAL '2 hours');

    -- Check 7: Active products with missing or invalid category
    SELECT COUNT(*) INTO v_missing_categories 
    FROM public.products p 
    LEFT JOIN public.categories c ON p.category_id = c.id 
    WHERE p.is_active = true AND c.id IS NULL;

    -- Check 8: Active products with empty or null image URL
    SELECT COUNT(*) INTO v_missing_images 
    FROM public.products 
    WHERE is_active = true AND (image_url IS NULL OR trim(image_url) = '');

    -- Calculate total action items
    v_action_count := v_negative_stock + v_invalid_prices + v_stuck_reservations + 
                      v_orphaned_order_items + v_orphaned_payments + v_unresolved_payments;

    IF v_negative_stock > 0 OR v_invalid_prices > 0 OR v_orphaned_order_items > 0 THEN
        v_status := 'ACTION_REQUIRED';
    ELSIF v_stuck_reservations > 0 OR v_unresolved_payments > 0 OR v_missing_images > 0 THEN
        v_status := 'DEGRADED';
    ELSE
        v_status := 'HEALTHY';
    END IF;

    RETURN jsonb_build_object(
        'status', v_status,
        'checked_at', now(),
        'action_required_count', v_action_count,
        'checks', jsonb_build_object(
            'negative_stock', v_negative_stock,
            'invalid_prices', v_invalid_prices,
            'stuck_reservations', v_stuck_reservations,
            'orphaned_order_items', v_orphaned_order_items,
            'orphaned_payments', v_orphaned_payments,
            'unresolved_payments', v_unresolved_payments,
            'missing_categories', v_missing_categories,
            'missing_images', v_missing_images
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. RPC: BUSINESS FUNNEL METRICS
-- Aggregates conversion rates across the critical user journey:
-- App Open -> Product View -> Add to Cart -> Checkout Started -> Payment Started -> Order Completed
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_business_funnel(
    p_start_date TIMESTAMPTZ DEFAULT (now() - INTERVAL '30 days'),
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS JSONB AS $$
DECLARE
    v_app_opens BIGINT := 0;
    v_product_views BIGINT := 0;
    v_cart_adds BIGINT := 0;
    v_checkout_starts BIGINT := 0;
    v_payment_starts BIGINT := 0;
    v_orders_completed BIGINT := 0;
    v_overall_conversion NUMERIC := 0.0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can access business funnel analytics';
    END IF;

    -- Aggregate counts from analytics_events
    SELECT 
        COUNT(*) FILTER (WHERE event_type = 'app_opened'),
        COUNT(*) FILTER (WHERE event_type = 'product_viewed'),
        COUNT(*) FILTER (WHERE event_type = 'cart_item_added'),
        COUNT(*) FILTER (WHERE event_type = 'checkout_started'),
        COUNT(*) FILTER (WHERE event_type = 'payment_started'),
        COUNT(*) FILTER (WHERE event_type = 'order_created' OR event_type = 'order_completed')
    INTO 
        v_app_opens,
        v_product_views,
        v_cart_adds,
        v_checkout_starts,
        v_payment_starts,
        v_orders_completed
    FROM public.analytics_events
    WHERE created_at >= p_start_date AND created_at <= p_end_date;

    -- Also check authoritative orders table for financial completed orders count if events are fresh
    IF v_orders_completed = 0 THEN
        SELECT COUNT(*) INTO v_orders_completed
        FROM public.orders
        WHERE created_at >= p_start_date AND created_at <= p_end_date
          AND status IN ('confirmed', 'processing', 'shipped', 'delivered');
    END IF;

    -- Calculate overall conversion rate
    IF v_app_opens > 0 THEN
        v_overall_conversion := ROUND((v_orders_completed::NUMERIC / v_app_opens::NUMERIC) * 100, 2);
    ELSIF v_product_views > 0 THEN
        v_overall_conversion := ROUND((v_orders_completed::NUMERIC / v_product_views::NUMERIC) * 100, 2);
    END IF;

    RETURN jsonb_build_object(
        'start_date', p_start_date,
        'end_date', p_end_date,
        'overall_conversion_percent', v_overall_conversion,
        'stages', jsonb_build_object(
            'app_opened', v_app_opens,
            'product_viewed', v_product_views,
            'cart_item_added', v_cart_adds,
            'checkout_started', v_checkout_starts,
            'payment_started', v_payment_starts,
            'order_completed', v_orders_completed
        ),
        'dropoffs', jsonb_build_object(
            'view_to_cart_pct', CASE WHEN v_product_views > 0 THEN ROUND(((v_product_views - v_cart_adds)::NUMERIC / v_product_views::NUMERIC) * 100, 1) ELSE 0 END,
            'cart_to_checkout_pct', CASE WHEN v_cart_adds > 0 THEN ROUND(((v_cart_adds - v_checkout_starts)::NUMERIC / v_cart_adds::NUMERIC) * 100, 1) ELSE 0 END,
            'checkout_to_payment_pct', CASE WHEN v_checkout_starts > 0 THEN ROUND(((v_checkout_starts - v_payment_starts)::NUMERIC / v_checkout_starts::NUMERIC) * 100, 1) ELSE 0 END,
            'payment_to_order_pct', CASE WHEN v_payment_starts > 0 THEN ROUND(((v_payment_starts - v_orders_completed)::NUMERIC / v_payment_starts::NUMERIC) * 100, 1) ELSE 0 END
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. RPC: AGGREGATED ADMIN DASHBOARD METRICS
-- Single lightweight round-trip for high-level business, catalog, order, and payment KPIs.
-- Avoids multiple unbounded client-side queries.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_admin_dashboard_metrics()
RETURNS JSONB AS $$
DECLARE
    -- Customer KPIs
    v_total_customers BIGINT := 0;
    v_new_customers_30d BIGINT := 0;

    -- Catalog KPIs
    v_total_products BIGINT := 0;
    v_active_products BIGINT := 0;
    v_low_stock_products BIGINT := 0;
    v_out_of_stock_products BIGINT := 0;

    -- Order KPIs
    v_total_orders BIGINT := 0;
    v_pending_orders BIGINT := 0;
    v_confirmed_orders BIGINT := 0;
    v_delivered_orders BIGINT := 0;
    v_cancelled_orders BIGINT := 0;
    v_total_revenue NUMERIC := 0.00;

    -- Payment KPIs
    v_successful_payments BIGINT := 0;
    v_failed_payments BIGINT := 0;
    v_refunded_payments BIGINT := 0;
    v_payment_failure_rate NUMERIC := 0.0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can fetch dashboard metrics';
    END IF;

    -- Customers
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE created_at >= now() - INTERVAL '30 days')
    INTO v_total_customers, v_new_customers_30d
    FROM public.profiles
    WHERE role = 'customer';

    -- Catalog
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active = true),
        COUNT(*) FILTER (WHERE stock_quantity > 0 AND stock_quantity <= 5),
        COUNT(*) FILTER (WHERE stock_quantity <= 0)
    INTO v_total_products, v_active_products, v_low_stock_products, v_out_of_stock_products
    FROM public.products;

    -- Orders
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'pending'),
        COUNT(*) FILTER (WHERE status IN ('confirmed', 'processing', 'shipped')),
        COUNT(*) FILTER (WHERE status = 'delivered'),
        COUNT(*) FILTER (WHERE status = 'cancelled'),
        COALESCE(SUM(total_amount) FILTER (WHERE status NOT IN ('cancelled', 'failed')), 0.00)
    INTO v_total_orders, v_pending_orders, v_confirmed_orders, v_delivered_orders, v_cancelled_orders, v_total_revenue
    FROM public.orders;

    -- Payments
    SELECT 
        COUNT(*) FILTER (WHERE status = 'captured'),
        COUNT(*) FILTER (WHERE status = 'failed'),
        COUNT(*) FILTER (WHERE status = 'refunded')
    INTO v_successful_payments, v_failed_payments, v_refunded_payments
    FROM public.payments;

    -- Calculate payment failure rate
    IF (v_successful_payments + v_failed_payments) > 0 THEN
        v_payment_failure_rate := ROUND(
            (v_failed_payments::NUMERIC / (v_successful_payments + v_failed_payments)::NUMERIC) * 100, 
            2
        );
    END IF;

    RETURN jsonb_build_object(
        'timestamp', now(),
        'customers', jsonb_build_object(
            'total', v_total_customers,
            'new_30d', v_new_customers_30d
        ),
        'catalog', jsonb_build_object(
            'total', v_total_products,
            'active', v_active_products,
            'low_stock', v_low_stock_products,
            'out_of_stock', v_out_of_stock_products
        ),
        'orders', jsonb_build_object(
            'total', v_total_orders,
            'pending', v_pending_orders,
            'confirmed', v_confirmed_orders,
            'delivered', v_delivered_orders,
            'cancelled', v_cancelled_orders,
            'total_revenue', v_total_revenue
        ),
        'payments', jsonb_build_object(
            'successful', v_successful_payments,
            'failed', v_failed_payments,
            'refunded', v_refunded_payments,
            'failure_rate_pct', v_payment_failure_rate
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 8. RPC: BOUNDED TELEMETRY RETENTION CLEANUP
-- Safely purges analytics events older than p_days_retention (default 90 days).
-- Bounded batch deletion (limit 5,000 rows per call) prevents lock escalation.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_cleanup_expired_telemetry(
    p_days_retention INT DEFAULT 90,
    p_batch_limit INT DEFAULT 5000
)
RETURNS INT AS $$
DECLARE
    v_deleted_count INT := 0;
    v_cutoff TIMESTAMPTZ;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can run telemetry cleanup';
    END IF;

    v_cutoff := now() - (COALESCE(p_days_retention, 90) || ' days')::INTERVAL;

    WITH doomed AS (
        SELECT id FROM public.analytics_events
        WHERE created_at < v_cutoff
        ORDER BY id ASC
        LIMIT LEAST(COALESCE(p_batch_limit, 5000), 10000)
    )
    DELETE FROM public.analytics_events
    WHERE id IN (SELECT id FROM doomed);

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
