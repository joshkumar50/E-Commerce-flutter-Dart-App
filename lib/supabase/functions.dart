// This file previously contained signIn() and signUp() helpers
// that mixed Supabase auth with UI navigation.
//
// These have been refactored into:
//   - lib/services/auth_service.dart  (pure auth logic)
//   - Screen-level handlers in each screen (navigation)
//
// This file is kept as a reference stub. It can be safely deleted.
