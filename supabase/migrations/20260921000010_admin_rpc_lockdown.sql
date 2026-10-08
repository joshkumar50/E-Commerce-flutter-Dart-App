-- =============================================================================
-- Migration 10: Admin RPC Lockdown (Defense-in-Depth)
-- Description: Explicitly REVOKE EXECUTE from anon role on sensitive RPCs
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.rpc_process_refund(UUID, NUMERIC, TEXT, BOOLEAN, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_admin_adjust_stock(BIGINT, INT, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_admin_update_order_status(UUID, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_update_product_occ(INT, INT, JSONB, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_run_data_health_check() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_get_admin_dashboard_metrics() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_get_business_funnel(TIMESTAMPTZ, TIMESTAMPTZ) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_cleanup_expired_telemetry(INT, INT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_log_admin_audit(TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_process_outbox_batch(INT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_reconcile_system_data() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_allocate_location_inventory(INT, TEXT, INT) FROM anon;
