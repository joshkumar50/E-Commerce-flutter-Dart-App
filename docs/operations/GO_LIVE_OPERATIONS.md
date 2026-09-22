# B-Buys Grocery Commerce Platform: Go-Live Operational Guide & First 30-Day Runbook

**Applications**: Customer Mobile App (`com.rast.opem`) & Admin Mobile App (`com.rast.opem.admin`)  
**Shared Backend**: Supabase / PostgreSQL 15, PgBouncer (Port 6543), Row Level Security (RLS)  
**Author**: Principal Release Engineer, SRE, and Production Operations Lead  
**Document Version**: 1.0.0-PROD  
**Effective Date**: September 2026  

---

## 1. Pre-Launch Readiness & Final Deployment Checklist

### A. Infrastructure & Backend Verification
- [x] **Supabase Production Project**: Dedicated production project provisioned in the desired regional availability zone.
- [x] **Connection Pooling**: PgBouncer transaction mode enabled on port `6543` to handle high client concurrency without PostgreSQL connection exhaustion.
- [x] **Database Migrations Applied (1 through 8)**:
  - `20260921000001_initial_schema.sql` (Core tables, trigram GIN indexes)
  - `20260921000002_row_level_security.sql` (RLS policies across all public tables)
  - `20260921000003_seed_data.sql` (Taxonomy and product catalog definitions)
  - `20260921000004_transaction_engine.sql` (Orders, payments, reservations, refunds, ledger)
  - `20260921000005_scalability_and_performance.sql` (PgBouncer grants, bounded search, partial indexes)
  - `20260921000006_post_launch_operations.sql` (Audit logging, telemetry, remote config kill switches)
  - `20260921000007_advanced_platform_evolution.sql` (Outbox table, dark stores, OCC product versioning)
  - `20260921000008_final_production_reconciliation.sql` (Atomic outbox insertions, webhook deduplication RPC, automated reconciliation sweeper)
- [x] **Storage Buckets & Policies**: `product-images` (public read, admin-only write) and `avatars` (user-scoped RLS).
- [x] **Realtime CDC Publications**: Enabled for `products`, `categories`, and `orders`.

### B. Client Compile-Time Environment Injection
Production builds strictly require runtime variables passed via `--dart-define-from-file=.env.production` or CI/CD environment secrets:
```bash
# Customer App Release Build (Google Play Store AAB)
flutter build appbundle --flavor customer -t lib/main.dart --dart-define-from-file=.env.production

# Admin App Release Build (Internal Distribution APK)
flutter build apk --flavor admin -t lib/main_admin.dart --dart-define-from-file=.env.production
```

Compile-time environment validation in [`lib/core/app_environment.dart`](file:///f:/mobile%20app/lib/core/app_environment.dart) aborts startup with a fatal `StateError` if `SUPABASE_URL` is empty, lacks `https://`, or contains placeholder values.

---

## 2. Release Artifact Specifications & Store Distribution

| Attribute | Customer Mobile App | Admin Mobile App |
| :--- | :--- | :--- |
| **Android Application ID** | `com.rast.opem` | `com.rast.opem.admin` |
| **Launcher App Name** | `B-Buys Grocery` | `B-Buys Admin` |
| **Entrypoint** | [`lib/main.dart`](file:///f:/mobile%20app/lib/main.dart) | [`lib/main_admin.dart`](file:///f:/mobile%20app/lib/main_admin.dart) |
| **Target SDK / Min SDK** | Target SDK 34 (Android 14) / Min SDK 21 | Target SDK 34 / Min SDK 21 |
| **Release Artifact Type** | Android App Bundle (`.aab`) | Universal Release APK (`.apk`) |
| **Distribution Channel** | Google Play Store (Public Track) | Google Play Internal Testing / Firebase App Distribution |
| **Signing Profile** | Production Keystore (`key.properties`) | Production Keystore (`key.properties`) |
| **OAuth Deep Link** | `io.supabase.bbuys://login-callback` | Google OAuth + Backend `is_admin()` gate |

---

## 3. Rollback & Emergency Forward-Fix Procedures

### Strategy 1: Instant Server-Side Feature Shedding & Kill Switches (0-minute downtime)
When an issue is localized to a non-critical feature or payment gateway latency:
1. Open Admin App > **Operations > Feature Flags & Kill Switches** (or invoke `RemoteConfigService`).
2. **Payment Gateway Latency**: Toggle `disable_payments = true`. App automatically hides digital payment and alerts users.
3. **Checkout Spike / Stock Discrepancy**: Toggle `disable_checkout = true`. Prevents further order placement while allowing catalog browsing.
4. **Critical Outage**: Toggle `maintenance_mode = true` with custom message. Customer app displays maintenance screen without crashes.
5. **Traffic Shedding**: Change `service_level` from `full` to `degraded` or `critical_checkout_only`. Banners and recommendations are dropped.

### Strategy 2: Database Recovery & Forward-Fixing
- **WAL-G Point-in-Time Recovery (PITR)**: Supabase continuous WAL archiving provides 5-minute RPO recovery window.
- **Controlled System Reconciliation**: Execute `rpc_reconcile_system_data()` to automatically release expired holds (>15 mins), fail stuck payments (>2h), and audit negative stock anomalies without touching valid completed orders.
- **Database Migrations**: All migrations are idempotent (`IF NOT EXISTS`, `CREATE OR REPLACE`). If an issue occurs, deploy a forward-fixing migration (e.g. Migration 9) rather than destructive rollback.

---

## 4. First 24-Hour Launch Telemetry & Monitoring Matrix

During the first 24 hours of launch, SRE and on-call engineers monitor the following primary indicators:

| Telemetry Metric | Target Threshold | Alert Threshold (P1) | Critical Threshold (P0) | Remediation Action |
| :--- | :--- | :--- | :--- | :--- |
| **API P95 Latency** | < 250 ms | > 600 ms for 5 mins | > 1500 ms for 3 mins | Check DB active connections via `pg_stat_activity`; verify PgBouncer pool depth. |
| **Checkout Success Rate** | > 98% | < 95% | < 90% | Inspect `inventory_reservations` and `payments` error codes in `payment_events`. |
| **Payment Verification Latency** | < 800 ms | > 2000 ms | > 5000 ms | Engage `payment_gateway` circuit breaker; check Razorpay webhook backlog. |
| **App Crash-Free Sessions** | > 99.8% | < 99.0% | < 97.5% | Inspect crash logs; deploy hotfix build; toggle offending feature flag. |
| **Negative Stock Anomalies** | **0** | **> 0** | **> 0** | Run `rpc_reconcile_system_data()`; lock affected product; check `inventory_ledger`. |
| **Outbox Dead-Letter Events** | **0** | > 5 | > 20 | Trigger `rpc_process_outbox_batch()`; check subscriber downstream service. |

---

## 5. First 7-Day Stability & Anomaly Audit

- **Day 1–2**: Validate session restoration across user devices and verify Google OAuth token refresh cycles.
- **Day 3–4**: Inspect `payment_events` table for duplicate webhook arrival patterns. Ensure all replay events returned `duplicate: true` with zero multiple charges.
- **Day 5–6**: Review Trigram GIN search queries for slow query logs (`pg_stat_statements`). Check user drop-off in search conversion funnel.
- **Day 7**: Run full weekly data consistency audit comparing:
  - Total captured amount in `public.payments` vs. Razorpay merchant settlement.
  - Inventory ledger quantity deltas vs. actual product stock quantities.

---

## 6. First 30-Day Recurring Operations Checklists

### Daily SRE Checklist (Morning & Evening Shifts)
1. **Health Check**: Run `DataHealthService.runHealthCheck()` via Admin App or automated cron.
2. **Reservation Sweeper**: Verify `rpc_expire_reservations()` is sweeping abandoned checkouts.
3. **Error Budget**: Review error rates in Supabase Dashboard (must remain < 0.1%).
4. **Order Status Verification**: Inspect any orders stuck in `pending_payment` for > 2 hours.

### Weekly SRE Checklist
1. **Database Vacuum & Index Health**: Verify PostgreSQL autovacuum is keeping `orders`, `inventory_ledger`, and `event_outbox` compact.
2. **Storage Growth**: Check S3 bucket usage and asset caching headers.
3. **Admin Audit Trail Review**: Inspect `admin_audit_logs` for unauthorized role escalation attempts or anomalous bulk stock adjustments.
4. **Security Secret Audit**: Re-verify zero API secrets logged in application monitoring.

### Monthly Platform Review
1. **Capacity & Scaling Review**: Compare peak active connections and query throughput against Phase 6 load baselines.
2. **Payment Fee & Reconciliation Review**: Reconcile refunds, chargebacks, and gateway transaction fees.
3. **Dependency & Security Patching**: Review Flutter SDK, Supabase client, and Gradle dependency advisories.

---

## 7. Incident Response Playbooks

### Playbook A: Payment Gateway Outage / Webhook Backlog
1. **Detection**: Spike in payment verification timeouts or uncaptured orders.
2. **Containment**: Remote config engages circuit breaker `payment_gateway_breaker` (transitions to `OPEN`).
3. **Customer Experience**: Checkout displays temporary notification: *"Online payments temporarily degraded; retrying..."*
4. **Recovery**: As provider recovers, circuit breaker enters `HALF_OPEN`, probes recovery, and transitions to `CLOSED`.
5. **Reconciliation**: Deliver queued webhooks to `rpc_process_payment_webhook`; verify orders transition to `confirmed`.

### Playbook B: Database Connection Exhaustion
1. **Detection**: Client queries return `503 Service Unavailable` or `connection limit exceeded`.
2. **Containment**: Switch client traffic to PgBouncer connection pooling port `6543` (transaction mode).
3. **Action**: Terminate idle client connections using `pg_terminate_backend(pid)` for connections idle > 5 mins.
4. **Prevention**: Ensure client services do not hold long-running open transactions.

### Playbook C: Security Credential Compromise
1. **Detection**: Suspicious activity in `admin_audit_logs` or leaked key alert.
2. **Containment**:
   - Rotate `SUPABASE_ANON_KEY` and `JWT_SECRET` in Supabase Project Settings.
   - Invalidate all active user sessions via `auth.admin.signOut()`.
   - Update CI/CD secret manager with new credentials and trigger immediate rebuild.

---

## 8. Customer Support Playbook & Escalation Matrix

### Scenario 1: Customer Reports Payment Debited but Order Not Confirmed
1. Support agent accesses Admin App > **Orders**.
2. Searches by Customer Email or Phone number.
3. If order is in `pending_payment`:
   - Checks payment transaction ID in Razorpay Dashboard.
   - If payment is `captured` in Razorpay: Invokes `rpc_process_payment_webhook` with payment details.
   - Order immediately updates to `confirmed`, reservation is committed, and push notification is triggered.

### Scenario 2: Customer Requests Cancellation & Refund
1. Support agent opens order in **Admin Order Detail**.
2. Verifies order has not yet entered `shipped` or `delivered` state.
3. Taps **"Process Refund"**, selects full amount, inputs reason, and checks **"Restock Inventory"**.
4. The system executes `rpc_process_refund`:
   - Payment provider initiates refund transaction.
   - Stock is restored atomically to product inventory.
   - `refund_restock` ledger record and admin audit log are created.
   - Order status transitions to `refunded`.
