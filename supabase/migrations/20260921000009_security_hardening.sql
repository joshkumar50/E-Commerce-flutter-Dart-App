-- =============================================================================
-- Migration 09: Security Hardening & Session Boundaries
-- =============================================================================

-- NOTE: All 23 requested tables (profiles, categories, products, product_images, 
-- addresses, wishlist_items, cart_items, orders, order_items, inventory_reservations, 
-- inventory_ledger, payments, payment_events, refunds, idempotency_keys, 
-- order_status_history, payment_status_history, analytics_events, admin_audit_logs, 
-- app_config, event_outbox, fulfillment_locations, inventory_by_location) 
-- have been verified to ALREADY have ROW LEVEL SECURITY enabled from prior migrations.

-- This migration serves as an explicit marker for Phase 3 security hardening.
-- If any missing tables were found, they would be enabled here:
-- ALTER TABLE public.<missing_table> ENABLE ROW LEVEL SECURITY;
