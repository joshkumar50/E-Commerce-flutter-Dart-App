# Supabase Production Runbook

## Supabase Auth Rate Limits

To ensure robust production security and prevent credential stuffing or brute-force attacks, the following Supabase Auth rate limits should be configured in the Supabase Dashboard (Authentication -> Rate Limits):

- **Sign In with Password (Token generation)**: 30 requests per hour per IP.
- **Sign Up**: 5 requests per hour per IP.
- **Send OTP (Phone/Email)**: 10 requests per hour per IP.
- **Verify OTP**: 15 requests per hour per IP.
- **Magic Link**: 10 requests per hour per IP.

Enforcing these limits is critical to preventing brute-force enumeration against customer accounts and mitigating volumetric API attacks on the Auth endpoints.

## CORS & Web Security Headers

- **Supabase Dashboard → Settings → API → Allowed Origins**: Restrict strictly to your production domain(s) (e.g., `https://bbuys.com`). Remove `*` or localhost from production.
- **Web Host Required Headers**: Ensure your web hosting provider (e.g., Vercel, Netlify, Nginx) serves the following security headers:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Content-Security-Policy: default-src 'self'; img-src 'self' https:; connect-src 'self' https://*.supabase.co`

## Database Recovery (WAL/PITR)

To guarantee no data loss during catastrophic failures:
1. Ensure **Point-in-Time Recovery (PITR)** is enabled in the Supabase Dashboard -> Database -> Backups.
2. Verify that **WAL (Write-Ahead Logging)** is capturing critical tables (Orders, Payments, Inventory Ledger).
3. Schedule quarterly test-restores of the database to a staging environment to verify backup integrity.
