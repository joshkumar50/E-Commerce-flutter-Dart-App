# B-Buys Production Operational Runbook & SRE Manual

## 1. System Architecture Overview

```
[ CUSTOMER FLUTTER APP ]              [ ADMIN FLUTTER APP ]
  (com.rast.opem)                       (com.rast.opem.admin)
       │                                     │
       │ (In-Memory Cache, Debounce)         │ (Keyset Pagination, Thumbnails)
       ▼                                     ▼
[ SUPABASE REST / POSTGREST CONNECTION POOLER (Supavisor Transaction Mode) ]
       │
       ├── DATABASE: PostgreSQL with RLS & GIN Trigram Search
       ├── AUTHENTICATION: Supabase Auth (Email + Google OAuth)
       ├── STORAGE: S3-Compatible Buckets (`product-images`, `avatars`)
       ├── REALTIME: WebSocket Scoped Event Streaming
       └── OBSERVABILITY: AppObservability Latency Tracker & Structured Logs
```

---

## 2. Daily & Weekly Operational Checks

### Daily SRE Checklist (Morning Shift)
1. **Error Rate & Health**: Check Supabase Dashboard > Reports > Error Rate (Target: < 0.1%).
2. **Checkout Success Rate**: Verify `orders` table confirmed/completed vs. cancelled/failed ratio (Target: > 98%).
3. **Reservation Sweeper Health**: Verify that `rpc_expire_reservations()` executed in the last 24h and no reservations remain stuck in `reserved` status beyond 15 minutes.
4. **Payment Reconciliation**: Compare successful Razorpay/payment charges against captured rows in `public.payments`.

### Weekly SRE Checklist
1. **Database Growth & Storage**: Review disk usage, WAL accumulation, and table sizes (`inventory_ledger`, `payment_events`).
2. **Index Usage & Performance**: Execute `pg_stat_user_indexes` to ensure trigram and composite indexes are actively serving queries.
3. **Backup Point-In-Time Verification**: Confirm continuous WAL archiving is healthy with an RPO < 5 minutes.
4. **Log Sanitization Audit**: Sample logs from the past 7 days to verify zero passwords, tokens, or payment secrets were recorded.

---

## 3. Incident Response Procedures

### Severity Classification
- **P0 (Critical Outage / Emergency)**: Data corruption, financial inconsistency, overselling, database down, security breach. Immediate paging (Response: < 15 mins).
- **P1 (Major Service Degradation)**: Checkout failure spike (> 1%), payment verification stalls, database connection exhaustion. (Response: < 30 mins).
- **P2 (Minor Degradation)**: Latency increase, temporary storage latency, non-critical realtime reconnects. (Response: < 2 hours).

### Standard Incident Workflow
```
1. DETECT    → Alert fires or user report received
2. CONFIRM   → Verify metric on operational dashboard
3. CONTAIN   → Activate kill-switch / feature flag if necessary
4. RECOVER   → Follow specific recovery playbook below
5. VERIFY    → Execute end-to-end smoke test
6. DOCUMENT  → Write Post-Incident Review (PIR) within 48h
```

---

## 4. Emergency Subsystem Procedures

### A. Emergency Payment Outage / Delayed Webhooks
**Scenario**: Payment provider API is experiencing latency or webhook delivery is backlogged.
1. **Customer Impact**: Customer completes payment in gateway, but order remains `payment_processing`.
2. **Procedure**:
   - Do NOT cancel orders immediately; the 15-minute reservation hold protects stock.
   - Run manual verification script or invoke `rpc_verify_payment` with the provider transaction ID.
   - If webhook backlog resolves, deduplication table `payment_events(provider_event_id)` safely ensures each webhook is processed exactly once without double-crediting.
3. **Provider Outage**: If provider is completely down, display in-app banner notifying users of temporary payment maintenance; do NOT allow checkout submission to complete with false success.

### B. Emergency Inventory Inconsistency / Overselling Alert
**Scenario**: Inconsistent stock detected or admin reports stock count mismatch.
1. **Procedure**:
   - Inspect immutable audit ledger:
     ```sql
     SELECT * FROM public.inventory_ledger 
     WHERE product_id = [AFFECTED_ID] 
     ORDER BY created_at DESC LIMIT 50;
     ```
   - Identify discrepancies between `stock_before`, `quantity_change`, and `stock_after`.
   - Use `rpc_admin_adjust_stock(p_product_id, p_new_quantity, p_reason)` to record authoritative reconciliation.
   - Never run raw `UPDATE products SET stock_quantity = ...` without logging an audit ledger record!

### C. Database Connection Exhaustion (Pool Saturation)
**Scenario**: PostgreSQL reports `FATAL: remaining connection slots are reserved`.
1. **Procedure**:
   - Verify connection mode: Clients MUST connect through Supavisor / PgBouncer (`port 6543`) in **Transaction Mode**, NOT direct session connection (`port 5432`).
   - Terminate rogue idle connections:
     ```sql
     SELECT pg_terminate_backend(pid) 
     FROM pg_stat_activity 
     WHERE state = 'idle in transaction' 
       AND state_change < now() - INTERVAL '2 minutes';
     ```

---

## 5. Rollback Strategies

### 1. Mobile App Rollback
- Mobile binaries (AAB/APKs) distributed through app stores cannot be instantly recalled.
- If a catastrophic mobile bug is released:
  - **Server-Side Mitigation**: Disable the affected endpoint or RPC in Supabase, returning a descriptive maintenance error.
  - **Fast-Track Hotfix**: Increment `versionCode` (e.g. `1.0.1+2`), build via GitHub Actions, and request emergency review on Google Play Console.

### 2. Database Migration Rollback
- Database migrations in `supabase/migrations/` are forward-compatible.
- **Rollback Rule**: Never run destructive rollbacks (`DROP TABLE`, `DROP COLUMN`) during active user traffic. Instead, apply a forward-fix migration that restores the prior column or function definition.

---

## 6. Key Rotation Procedures

| Secret | Rotation Frequency | Rotation Procedure |
|---|---|---|
| **Supabase JWT Secret** | Annually or upon breach | Supabase Dashboard > Settings > API > Generate new JWT secret. (Requires re-authenticating active mobile sessions). |
| **Supabase Anon Key** | Bi-annually | Generate new publishable API key in Dashboard; update CI/CD secrets; redeploy app. |
| **Razorpay Webhook Secret** | Quarterly | Generate new secret in Razorpay Dashboard; update Edge Function environment variables; verify signature handling. |
| **Google OAuth Client Secrets**| Annually | Rotate in Google Cloud Console > APIs & Credentials; update Supabase Auth Google provider settings. |
| **Android Upload Keystore** | On Compromise | Request upload key reset through Google Play Console Support. Google Play App Signing will switch to the new upload certificate without disrupting end-users. |

---

## 7. Backup & Restore Verification

- **RPO (Recovery Point Objective)**: 5 Minutes (continuous WAL streaming).
- **RTO (Recovery Time Objective)**: 30 Minutes.
- **Backup Verification Status**: **VERIFIED**. Schema, migrations, RPCs, and state machines are codified in Git and reproducible from zero via `supabase db push`.
- **Restoration Test Procedure**:
  1. Create a temporary staging project: `supabase projects create bbuys-restore-test`.
  2. Apply versioned migrations in order: `20260921000001` through `20260921000005`.
  3. Verify RLS policies and table constraints via automated test suite.
  4. Tear down temporary test project.
