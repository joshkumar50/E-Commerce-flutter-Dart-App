CREATE OR REPLACE FUNCTION public.prevent_role_self_escalation()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role <> NEW.role AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Role escalation not permitted' USING ERRCODE = 'P0013';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_role_escalation
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.prevent_role_self_escalation();


CREATE OR REPLACE FUNCTION public.raise_immutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table % is immutable', TG_TABLE_NAME USING ERRCODE = 'P0013';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_immutable ON public.admin_audit_logs;
CREATE TRIGGER trg_audit_immutable
    BEFORE UPDATE OR DELETE ON public.admin_audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.raise_immutable();

DROP TRIGGER IF EXISTS trg_inventory_ledger_immutable ON public.inventory_ledger;
CREATE TRIGGER trg_inventory_ledger_immutable
    BEFORE UPDATE OR DELETE ON public.inventory_ledger
    FOR EACH ROW EXECUTE FUNCTION public.raise_immutable();
