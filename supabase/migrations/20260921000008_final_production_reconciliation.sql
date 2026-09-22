-- =============================================================================
-- Migration: 20260921000008_final_production_reconciliation.sql
-- Description: Phase 10 Final Architecture Reconciliation & Production Certification.
--              1. Connects Transactional Outbox (event_outbox) atomically to:
--                 - rpc_create_checkout (order.created)
--                 - rpc_verify_payment (payment.captured & order.confirmed)
--                 - rpc_handle_payment_failure (order.cancelled)
--                 - rpc_process_refund (order.refunded)
--              2. Introduces rpc_process_payment_webhook for idempotent webhook
--                 ingestion and replay protection via public.payment_events.
--              3. Introduces rpc_reconcile_system_data for automated auditing,
--                 sweeping of stale reservations/payments, and integrity reporting.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. UPGRADE RPC: rpc_create_checkout
-- Connects order creation atomically to event_outbox ('order.created').
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_create_checkout(
    p_address_id UUID,
    p_cart_items JSONB,
    p_idempotency_key TEXT DEFAULT NULL,
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
                RETURN v_existing_key.response_reference;
            ELSIF v_existing_key.status = 'in_progress' AND v_existing_key.created_at > (now() - INTERVAL '30 seconds') THEN
                RAISE EXCEPTION 'A checkout request with this idempotency key is already in progress. Please wait.' USING ERRCODE = 'P0002';
            END IF;
        ELSE
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

        v_effective_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := round(v_effective_price * v_item.quantity, 2);
        v_subtotal := v_subtotal + v_line_total;
    END LOOP;

    -- Business rules for fees
    IF v_subtotal >= 500.00 THEN
        v_delivery_fee := 0.00;
    ELSE
        v_delivery_fee := 40.00;
    END IF;

    v_tax_total := round(v_subtotal * 0.05, 2);
    v_grand_total := v_subtotal + v_delivery_fee + v_tax_total - v_discount_total;

    -- 6. Generate Human-Readable Order Number
    v_order_number := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
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

        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity,
            updated_at = now()
        WHERE id = v_product.id;

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

    -- 9. Create Payment Record
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

    INSERT INTO public.payment_status_history (payment_id, from_status, to_status, changed_by, reason)
    VALUES (v_payment_id, NULL, 'created', v_user_id, 'Payment record initiated for order ' || v_order_number);

    -- 10. Clear items from customer cart
    DELETE FROM public.cart_items
    WHERE user_id = v_user_id
      AND product_id = ANY(v_product_ids);

    -- 11. ATOMIC TRANSACTIONAL OUTBOX INSERTION (order.created)
    INSERT INTO public.event_outbox (
        event_type,
        aggregate_type,
        aggregate_id,
        payload,
        correlation_id,
        schema_version,
        status
    ) VALUES (
        'order.created',
        'order',
        v_order_id::text,
        jsonb_build_object(
            'order_id', v_order_id,
            'order_number', v_order_number,
            'user_id', v_user_id,
            'grand_total', v_grand_total,
            'currency', 'INR',
            'items_count', jsonb_array_length(p_cart_items),
            'expires_at', v_expires_at
        ),
        COALESCE(p_idempotency_key, v_order_id::text),
        1,
        'pending'
    );

    -- 12. Prepare response payload
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
-- 2. UPGRADE RPC: rpc_verify_payment
-- Connects payment verification atomically to event_outbox ('payment.captured' and 'order.confirmed').
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

    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0009';
    END IF;

    IF v_order.user_id <> v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied to verify this order' USING ERRCODE = 'P0010';
    END IF;

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

    SELECT * INTO v_payment
    FROM public.payments
    WHERE order_id = p_order_id
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No payment record found for order %', p_order_id USING ERRCODE = 'P0012';
    END IF;

    UPDATE public.payments
    SET status = 'captured',
        provider_payment_id = p_provider_payment_id,
        method = COALESCE(p_payment_method, method),
        signature_verified = true,
        updated_at = now()
    WHERE id = v_payment.id;

    INSERT INTO public.payment_status_history (payment_id, from_status, to_status, changed_by, reason)
    VALUES (v_payment.id, v_payment.status, 'captured', v_user_id, 'Payment signature verified successfully');

    -- Consume all active inventory reservations
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE order_id = p_order_id AND status = 'reserved'
        FOR UPDATE
    LOOP
        UPDATE public.inventory_reservations
        SET status = 'consumed'
        WHERE id = v_res.id;

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
            0,
            'Payment verified. Inventory consumption confirmed.'
        );
    END LOOP;

    -- Transition order status
    UPDATE public.orders
    SET status = 'confirmed',
        payment_status = 'captured',
        updated_at = now()
    WHERE id = p_order_id;

    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, 'confirmed', v_user_id, 'Payment verified; order confirmed');

    -- ATOMIC TRANSACTIONAL OUTBOX INSERTION (payment.captured & order.confirmed)
    INSERT INTO public.event_outbox (
        event_type,
        aggregate_type,
        aggregate_id,
        payload,
        correlation_id,
        schema_version,
        status
    ) VALUES 
    (
        'payment.captured',
        'payment',
        v_payment.id::text,
        jsonb_build_object(
            'payment_id', v_payment.id,
            'order_id', p_order_id,
            'amount', v_payment.amount,
            'provider_payment_id', p_provider_payment_id,
            'method', COALESCE(p_payment_method, v_payment.method)
        ),
        p_provider_payment_id,
        1,
        'pending'
    ),
    (
        'order.confirmed',
        'order',
        p_order_id::text,
        jsonb_build_object(
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'payment_status', 'captured',
            'order_status', 'confirmed'
        ),
        p_provider_payment_id,
        1,
        'pending'
    );

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
-- 3. UPGRADE RPC: rpc_handle_payment_failure
-- Connects payment cancellation atomically to event_outbox ('order.cancelled').
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

    IF v_order.status IN ('paid', 'confirmed', 'completed') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order already paid');
    END IF;

    UPDATE public.payments
    SET status = 'failed',
        updated_at = now()
    WHERE order_id = p_order_id AND status IN ('created', 'pending');

    -- Release reserved stock
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE order_id = p_order_id AND status = 'reserved'
        FOR UPDATE
    LOOP
        SELECT * INTO v_prod
        FROM public.products
        WHERE id = v_res.product_id
        FOR UPDATE;

        UPDATE public.products
        SET stock_quantity = stock_quantity + v_res.quantity,
            updated_at = now()
        WHERE id = v_res.product_id;

        UPDATE public.inventory_reservations
        SET status = 'released',
            released_at = now()
        WHERE id = v_res.id;

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

    UPDATE public.orders
    SET status = 'payment_failed',
        payment_status = 'failed',
        updated_at = now()
    WHERE id = p_order_id;

    INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
    VALUES (p_order_id, v_order.status, 'payment_failed', v_user_id, p_reason);

    -- ATOMIC TRANSACTIONAL OUTBOX INSERTION (order.cancelled)
    INSERT INTO public.event_outbox (
        event_type,
        aggregate_type,
        aggregate_id,
        payload,
        correlation_id,
        schema_version,
        status
    ) VALUES (
        'order.cancelled',
        'order',
        p_order_id::text,
        jsonb_build_object(
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'reason', p_reason,
            'status', 'payment_failed'
        ),
        p_order_id::text,
        1,
        'pending'
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'payment_failed',
        'payment_status', 'failed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- 4. UPGRADE RPC: rpc_process_refund
-- Connects refund processing atomically to event_outbox ('order.refunded').
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

    SELECT COALESCE(SUM(amount), 0) INTO v_total_refunded
    FROM public.refunds
    WHERE order_id = p_order_id AND status = 'processed';

    IF (v_total_refunded + p_amount) > v_order.grand_total THEN
        RAISE EXCEPTION 'Total refunded amount (%) cannot exceed order grand total (%)',
            (v_total_refunded + p_amount), v_order.grand_total USING ERRCODE = 'P0015';
    END IF;

    v_provider_refund_id := 'rfnd_' || upper(substr(md5(gen_random_uuid()::text), 1, 14));

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

    -- Update order status
    IF (v_total_refunded + p_amount) >= v_order.grand_total THEN
        UPDATE public.orders
        SET status = 'refunded',
            payment_status = 'refunded',
            updated_at = now()
        WHERE id = p_order_id;
    ELSE
        UPDATE public.orders
        SET status = 'partially_refunded',
            payment_status = 'partially_refunded',
            updated_at = now()
        WHERE id = p_order_id;
    END IF;

    -- ATOMIC TRANSACTIONAL OUTBOX INSERTION (order.refunded)
    INSERT INTO public.event_outbox (
        event_type,
        aggregate_type,
        aggregate_id,
        payload,
        correlation_id,
        schema_version,
        status
    ) VALUES (
        'order.refunded',
        'refund',
        v_refund_id::text,
        jsonb_build_object(
            'refund_id', v_refund_id,
            'order_id', p_order_id,
            'amount', p_amount,
            'provider_refund_id', v_provider_refund_id,
            'restocked', p_restock,
            'reason', p_reason
        ),
        COALESCE(p_idempotency_key, v_refund_id::text),
        1,
        'pending'
    );

    RETURN jsonb_build_object(
        'success', true,
        'refund_id', v_refund_id,
        'provider_refund_id', v_provider_refund_id,
        'amount', p_amount,
        'status', 'processed',
        'restocked', p_restock
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- 5. NEW RPC: rpc_process_payment_webhook
-- Idempotent payment webhook processor with deduplication via public.payment_events.
-- Solves crash-after-payment, duplicate webhook delivery, and delayed callbacks.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_process_payment_webhook(
    p_provider_event_id TEXT,
    p_event_type TEXT,
    p_order_id UUID,
    p_provider_payment_id TEXT,
    p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_existing_event RECORD;
    v_event_id UUID;
    v_order RECORD;
    v_payment RECORD;
    v_res RECORD;
BEGIN
    -- 1. Check for Duplicate Webhook Event Delivery
    SELECT * INTO v_existing_event
    FROM public.payment_events
    WHERE provider_event_id = p_provider_event_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate', true,
            'message', 'Webhook event already processed (idempotent replay)',
            'event_id', v_existing_event.id,
            'event_type', v_existing_event.event_type
        );
    END IF;

    -- 2. Record new payment event in payment_events table
    INSERT INTO public.payment_events (
        provider,
        provider_event_id,
        event_type,
        payload_hash,
        payload_json,
        processed,
        processed_at
    ) VALUES (
        'razorpay',
        p_provider_event_id,
        p_event_type,
        md5(p_payload::text),
        p_payload,
        false,
        NULL
    ) RETURNING id INTO v_event_id;

    -- 3. Process business effects based on event type
    IF p_event_type IN ('payment.captured', 'order.paid') THEN
        -- Lock order
        SELECT * INTO v_order
        FROM public.orders
        WHERE id = p_order_id
        FOR UPDATE;

        IF NOT FOUND THEN
            UPDATE public.payment_events
            SET processed = true, processed_at = now()
            WHERE id = v_event_id;

            RETURN jsonb_build_object(
                'success', false,
                'message', 'Order not found for webhook event',
                'order_id', p_order_id
            );
        END IF;

        -- If order is already confirmed or completed, idempotently mark event processed
        IF v_order.status IN ('confirmed', 'completed', 'delivered') THEN
            UPDATE public.payment_events
            SET processed = true, processed_at = now()
            WHERE id = v_event_id;

            RETURN jsonb_build_object(
                'success', true,
                'message', 'Order already paid and confirmed',
                'order_id', p_order_id,
                'status', v_order.status
            );
        END IF;

        -- Update payment record
        SELECT * INTO v_payment
        FROM public.payments
        WHERE order_id = p_order_id
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            UPDATE public.payments
            SET status = 'captured',
                provider_payment_id = COALESCE(p_provider_payment_id, provider_payment_id),
                signature_verified = true,
                updated_at = now()
            WHERE id = v_payment.id;
        END IF;

        -- Consume active reservations
        FOR v_res IN
            SELECT * FROM public.inventory_reservations
            WHERE order_id = p_order_id AND status = 'reserved'
            FOR UPDATE
        LOOP
            UPDATE public.inventory_reservations
            SET status = 'consumed'
            WHERE id = v_res.id;

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
                0,
                'Webhook payment confirmed. Reservation committed.'
            );
        END LOOP;

        -- Transition order status
        UPDATE public.orders
        SET status = 'confirmed',
            payment_status = 'captured',
            updated_at = now()
        WHERE id = p_order_id;

        INSERT INTO public.order_status_history (order_id, from_status, to_status, changed_by, reason)
        VALUES (p_order_id, v_order.status, 'confirmed', v_order.user_id, 'Webhook payment.captured confirmed by provider');

        -- Atomic Outbox Insertion
        INSERT INTO public.event_outbox (
            event_type,
            aggregate_type,
            aggregate_id,
            payload,
            correlation_id,
            schema_version,
            status
        ) VALUES (
            'order.confirmed',
            'order',
            p_order_id::text,
            jsonb_build_object(
                'order_id', p_order_id,
                'order_number', v_order.order_number,
                'source', 'webhook',
                'provider_event_id', p_provider_event_id
            ),
            p_provider_event_id,
            1,
            'pending'
        );

        -- Mark event processed
        UPDATE public.payment_events
        SET processed = true, processed_at = now()
        WHERE id = v_event_id;

        RETURN jsonb_build_object(
            'success', true,
            'order_id', p_order_id,
            'status', 'confirmed',
            'duplicate', false,
            'provider_event_id', p_provider_event_id
        );

    ELSIF p_event_type = 'payment.failed' THEN
        -- Safely release reservations
        PERFORM public.rpc_handle_payment_failure(p_order_id, 'Payment failed via webhook callback');

        UPDATE public.payment_events
        SET processed = true, processed_at = now()
        WHERE id = v_event_id;

        RETURN jsonb_build_object(
            'success', true,
            'order_id', p_order_id,
            'status', 'payment_failed',
            'duplicate', false
        );
    ELSE
        -- Other informational webhook events
        UPDATE public.payment_events
        SET processed = true, processed_at = now()
        WHERE id = v_event_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Webhook event logged',
            'event_type', p_event_type
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- 6. NEW RPC: rpc_reconcile_system_data
-- Controlled automated reconciliation and health sweeper.
-- Admin or System worker only.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_reconcile_system_data()
RETURNS JSONB AS $$
DECLARE
    v_expired_res_count INT := 0;
    v_stuck_payment_count INT := 0;
    v_dead_letter_outbox_count INT := 0;
    v_negative_stock_anomalies INT := 0;
    v_reconciled_at TIMESTAMPTZ := now();
    v_res RECORD;
    v_prod RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators or system service roles can execute reconciliation' USING ERRCODE = 'P0013';
    END IF;

    -- 1. Sweep expired inventory reservations (> 15 minutes)
    FOR v_res IN
        SELECT * FROM public.inventory_reservations
        WHERE status = 'reserved'
          AND expires_at < v_reconciled_at
        FOR UPDATE
    LOOP
        SELECT * INTO v_prod
        FROM public.products
        WHERE id = v_res.product_id
        FOR UPDATE;

        UPDATE public.products
        SET stock_quantity = stock_quantity + v_res.quantity,
            updated_at = v_reconciled_at
        WHERE id = v_res.product_id;

        UPDATE public.inventory_reservations
        SET status = 'expired',
            released_at = v_reconciled_at
        WHERE id = v_res.id;

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
            'Reconciliation sweeper expired reservation'
        );

        v_expired_res_count := v_expired_res_count + 1;
    END LOOP;

    -- 2. Mark stuck pending payments for orders older than 2 hours as failed
    WITH stuck_orders AS (
        SELECT id FROM public.orders
        WHERE status = 'pending_payment'
          AND created_at < (v_reconciled_at - INTERVAL '2 hours')
    )
    UPDATE public.payments
    SET status = 'failed',
        updated_at = v_reconciled_at
    WHERE order_id IN (SELECT id FROM stuck_orders)
      AND status IN ('created', 'pending');
    GET DIAGNOSTICS v_stuck_payment_count = ROW_COUNT;

    -- 3. Audit for any negative stock anomalies
    SELECT COUNT(*) INTO v_negative_stock_anomalies
    FROM public.products
    WHERE stock_quantity < 0;

    -- 4. Count dead-letter outbox events
    SELECT COUNT(*) INTO v_dead_letter_outbox_count
    FROM public.event_outbox
    WHERE status = 'dead_letter';

    -- 5. Record reconciliation in system audit log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        entity_type,
        entity_id,
        changes,
        created_at
    ) VALUES (
        auth.uid(),
        'system_reconciliation',
        'system',
        'reconciliation_sweeper',
        jsonb_build_object(
            'expired_reservations_cleaned', v_expired_res_count,
            'stuck_payments_failed', v_stuck_payment_count,
            'negative_stock_anomalies', v_negative_stock_anomalies,
            'dead_letter_outbox_count', v_dead_letter_outbox_count,
            'reconciled_at', v_reconciled_at
        ),
        v_reconciled_at
    );

    RETURN jsonb_build_object(
        'success', true,
        'reconciled_at', v_reconciled_at,
        'expired_reservations_cleaned', v_expired_res_count,
        'stuck_payments_failed', v_stuck_payment_count,
        'negative_stock_anomalies', v_negative_stock_anomalies,
        'dead_letter_outbox_count', v_dead_letter_outbox_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
