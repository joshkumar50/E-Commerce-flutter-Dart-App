# Google Play Store Readiness & Compliance Guide

## 1. Application Identities & Flavor Separation

| Application | Android Package Name (Application ID) | App Name (Launcher Label) | Distribution Strategy |
|---|---|---|---|
| **Customer App** | `com.rast.opem` | **B-Buys Grocery** | **Public Production Track** (Google Play Store) |
| **Admin App** | `com.rast.opem.admin` | **B-Buys Admin** | **Closed Internal Testing Track** (Restricted to Store Employees/Managers) |

Both apps use distinct application IDs, allowing both to be installed side-by-side on the same physical device without conflict.

---

## 2. Google Play Store Metadata (Customer App)

- **Application Title**: B-Buys Grocery
- **Category**: Shopping / Food & Drink
- **Short Description** (Max 80 chars):
  *Fresh groceries, farm-fresh produce, dairy, and daily essentials delivered fast.*
- **Full Description** (Max 4000 chars):
  > Welcome to B-Buys Grocery — your neighborhood grocery market delivered to your doorstep!
  >
  > Browse a complete selection of farm-fresh fruits, crisp vegetables, dairy products, bakery goods, and household staples. Enjoy real-time stock availability, seamless search, atomic multi-item cart management, and instant digital payment checkout.
  >
  > Features:
  > • 100% Real-Time Catalog: Always know what's in stock before you order.
  > • Instant Substring Search: Find fresh milk, eggs, bread, or fruits in milliseconds.
  > • Secure Checkout: Encrypted payment processing with instant order confirmation.
  > • Live Order Tracking: Real-time updates as your order is packed and dispatched.
  > • Favorites & Wishlist: One-tap access to your regular grocery essentials.
  >
  > Download B-Buys today for a fresher, faster grocery shopping experience!

---

## 3. Play Store Technical Compliance Checklist

- [x] **Target SDK 34 (Android 14)**: Configured in `android/app/build.gradle`.
- [x] **Minimum SDK 21 (Android 5.0+)**: Broad compatibility across 99%+ active Android devices.
- [x] **Android App Bundle (.aab)**: Configured via `flutter build appbundle`.
- [x] **64-bit Architecture**: Standard Flutter engine includes `arm64-v8a` and `x86_64` native binaries.
- [x] **Permission Minimization**: Removed deprecated `WRITE_EXTERNAL_STORAGE`. Only standard `INTERNET` and `ACCESS_NETWORK_STATE` permissions requested.
- [x] **Deep Link Safety**: Separated `LAUNCHER` intent filter from `io.supabase.bbuys://login-callback` OAuth redirect filter.

---

## 4. Google Play Data Safety Declaration

When completing the Google Play Console Data Safety questionnaire, declare the following:

| Data Type | Purpose | Ephemeral vs. Stored | Shared with Third Parties? |
|---|---|---|---|
| **Name & Email** | Account Management, Authentication | Stored in `public.profiles` | No |
| **Physical Address** | Order Delivery & Logistics | Stored in `public.addresses` | No |
| **Purchase History** | Order Fulfillment, Invoicing, Refunds | Stored in `public.orders` | No (Processed via Payment Gateway) |
| **Diagnostics / Crash Logs** | App Performance & Bug Triage | Ephemeral / Aggregated | No (Sanitized, zero credentials logged) |

### Security Measures Declared:
- **Data in Transit**: All communications encrypted over HTTPS/TLS 1.3.
- **Data at Rest**: Database secured with Row Level Security (RLS).
- **Data Deletion Mechanism**: Users can request account and address deletion through customer profile settings.

---

## 5. Division of Responsibilities (Crucial Boundary)

### What the AI Assistant (Cursor) Completed:
1. Hardened Gradle build configuration with flavor separation (`customer` vs `admin`).
2. Removed legacy permissions and fixed deep-link intent filters.
3. Created `AppEnvironment` compile-time credential verification.
4. Implemented automated GitHub Actions CI/CD workflow (`.github/workflows/production_ci.yml`).
5. Configured release signing automation with `key.properties` fallback.
6. Conducted zero-leak secret audit.
7. Prepared SRE Operational Runbook and Play Store metadata.

### [MANUAL ACTION REQUIRED BY APPLICATION OWNER]:
1. **Google Play Developer Account**: Register at [play.google.com/console](https://play.google.com/console) ($25 one-time registration fee).
2. **Generate Production Keystore**:
   Run on your local terminal:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   Save the generated `upload-keystore.jks` in a secure location and configure `android/key.properties` (never commit this to Git).
3. **Public Privacy Policy URL**: Host a publicly accessible privacy policy web page and enter the URL in Play Console.
4. **Google Cloud OAuth Consent Screen**: Set up OAuth 2.0 Web and Android Client IDs matching your upload keystore SHA-1 fingerprint in the Google Cloud Console.
5. **App Review Questionnaire**: Submit content rating, target audience, and news app declarations in the Google Play Console UI.
