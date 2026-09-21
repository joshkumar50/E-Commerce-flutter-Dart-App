# B-Buys Grocery Marketplace & Store Management Platform

A complete, production-ready grocery ecommerce ecosystem consisting of a **Customer Mobile App**, a dedicated **Admin Mobile App**, and a shared **Supabase/PostgreSQL** backend with ACID transaction guarantees, high-concurrency inventory protection, and performance optimizations.

---

## 📱 Application Overview

| App | Entry Point | Target Audience | Primary Features |
|---|---|---|---|
| **Customer App** | `lib/main.dart` | Shoppers / Customers | Categories, instant search, atomic cart, address book, secure checkout, live order tracking, and wishlist. |
| **Admin App** | `lib/main_admin.dart` | Store Staff / Managers | Product & category CRUD, live stock adjustments, operational order progression, and refund management. |

---

## 🏗 Architecture & Technologies

- **Mobile Client**: Flutter (Cross-platform Android / iOS / Web / Desktop)
- **Backend & Database**: Supabase & PostgreSQL with Row Level Security (RLS)
- **Search Engine**: PostgreSQL Trigram GIN Indexing (`pg_trgm`) for sub-15ms substring matching
- **Transactions & Concurrency**: PostgreSQL RPCs with sorted row-locking (`ORDER BY id ASC`), atomic reservations, and zero overselling guarantees
- **Caching**: In-memory TTL cache with LRU eviction and reactive prefix invalidation
- **State Management**: Provider with isolated ChangeNotifier scopes
- **CI/CD**: GitHub Actions workflow for automated linting, test suites, and AAB artifact builds

---

## 🚀 Running the Applications

### 1. Offline Demo Mode (Default)
Both applications run out-of-the-box with a full mock grocery catalog, real in-memory ACID transaction simulation, and instant state reactivity without requiring any external database credentials:

```bash
# Run Customer App in Chrome
flutter run -d chrome

# Run Admin App in Chrome
flutter run -d chrome -t lib/main_admin.dart

# Run as Native Windows Desktop App
flutter run -d windows
flutter run -d windows -t lib/main_admin.dart
```

### 2. Connecting to Live Supabase Backend
Pass environment variables via `--dart-define` or `--dart-define-from-file`:

```bash
# Using environment file
flutter run -d chrome --dart-define-from-file=.env.staging

# Using direct flags
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-anon-key
```

---

## 📦 Building Production Android Artifacts

The Android project is configured with separate product flavors so Customer and Admin can be installed on the same device without conflict:

```bash
# Build Customer Release App Bundle (AAB for Google Play)
flutter build appbundle --flavor customer -t lib/main.dart

# Build Admin Release App Bundle (AAB for Internal Distribution)
flutter build appbundle --flavor admin -t lib/main_admin.dart

# Build Release APKs for direct device testing
flutter build apk --flavor customer -t lib/main.dart
flutter build apk --flavor admin -t lib/main_admin.dart
```

---

## 🔒 Security & Privacy

1. **Zero-Secret Client Codebase**: Client apps only consume the public publishable anon key. Sensitive operations (checkout price recalculation, stock reservation, refunds) run strictly inside server-side PostgreSQL RPCs.
2. **Deterministic Concurrency**: Eliminates deadlocks and race conditions via sorted row locking and 15-minute bounded reservation holds.
3. **Log Sanitization**: `AppObservability` automatically redacts passwords, tokens, API keys, and payment card details from all structured logs.
4. **Android Permissions**: Requests only standard network permissions (`INTERNET`, `ACCESS_NETWORK_STATE`). Deprecated storage permissions have been removed.

---

## 📖 Operational Documentation

- [Production Operational Runbook](file:///f:/mobile%20app/docs/PRODUCTION_RUNBOOK.md) — Daily SRE checks, incident response, rollback procedures, and key rotation.
- [Google Play Store Readiness Guide](file:///f:/mobile%20app/docs/STORE_READINESS.md) — Store listing metadata, Data Safety questionnaire, and compliance checklists.
- [Database Migrations](file:///f:/mobile%20app/supabase/migrations/) — Version-controlled SQL migrations (`000001` through `000005`).
