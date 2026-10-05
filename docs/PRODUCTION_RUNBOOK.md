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

## Crash Reporting & PII Scrub

**NEVER send raw PII (Personally Identifiable Information) to crash reporters.**

If implementing crash reporting in production, you must explicitly redact all user PII (emails, phone numbers, JWTs, etc.) from metadata and breadcrumbs before transmission.

**Recommended Approach (Sentry):**
Use Sentry with a `beforeSend` hook to scrub payloads:

```dart
SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN';
    options.beforeSend = (event, {hint}) {
      final jwtRegex = RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+');
      
      // Example scrub of breadcrumbs
      final scrubbedBreadcrumbs = event.breadcrumbs?.map((b) {
        var msg = b.message?.replaceAll(jwtRegex, '[REDACTED_JWT]');
        // Add more scrubbing logic here for emails/phones
        return b.copyWith(message: msg);
      }).toList();
      
      return event.copyWith(breadcrumbs: scrubbedBreadcrumbs);
    };
  },
  appRunner: () => runApp(const MyApp()),
);
```

**Alternative Approach (Firebase Crashlytics):**
If using Firebase Crashlytics, NEVER call `setUserIdentifier()` with an email or phone number. Instead, use a one-way hash of the User ID:
```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

// ...
final hashedUserId = sha256.convert(utf8.encode(user.id)).toString();
FirebaseCrashlytics.instance.setUserIdentifier(hashedUserId);
```

## Post-Deploy Verification (Supabase Advisors)

**Steps:**
1. Open Supabase Dashboard → Database → Advisors
2. Run ALL rules (SECURITY + PERFORMANCE)
3. Resolve every SECURITY lint. Common ones:
   - **"RLS disabled on table"** → enable RLS
   - **"Function search_path mutable"** → add `SET search_path = public, pg_temp`
   - **"SECURITY DEFINER function executable by anon"** → REVOKE from anon
   - **"Public bucket exposes objects"** → review bucket RLS policies
4. Document PERFORMANCE lints as backlog items in Jira/GitHub Issues.
