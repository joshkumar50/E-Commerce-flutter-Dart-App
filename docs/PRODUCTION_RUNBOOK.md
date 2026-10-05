# Supabase Production Runbook

## Supabase Auth Rate Limits

To ensure robust production security and prevent credential stuffing or brute-force attacks, the following Supabase Auth rate limits should be configured in the Supabase Dashboard (Authentication -> Rate Limits):

- **Sign In with Password (Token generation)**: 30 requests per hour per IP.
- **Sign Up**: 5 requests per hour per IP.
- **Send OTP (Phone/Email)**: 10 requests per hour per IP.
- **Verify OTP**: 15 requests per hour per IP.
- **Magic Link**: 10 requests per hour per IP.

Enforcing these limits is critical to preventing brute-force enumeration against customer accounts and mitigating volumetric API attacks on the Auth endpoints.
