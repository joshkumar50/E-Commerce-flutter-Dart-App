# Phase 7 Tasks — Final Production Release, Security, CI/CD, App Signing, Store Readiness & Operations

## 1. Android Build & Manifest Hardening
- [x] Fix Gradle syntax and block nesting in `android/app/build.gradle`
- [x] Upgrade `targetSdkVersion` to 34 for Google Play Store compliance
- [x] Configure Android release signing with `key.properties` (with safe debug fallback)
- [x] Verify independent identities: `com.rast.opem` (Customer) vs `com.rast.opem.admin` (Admin)
- [x] Remove deprecated `WRITE_EXTERNAL_STORAGE` from `android/app/src/main/AndroidManifest.xml`
- [x] Add explicit `INTERNET` and `ACCESS_NETWORK_STATE` permissions
- [x] Separate launcher `<intent-filter>` from OAuth redirect filter with correct `io.supabase.bbuys` scheme

## 2. Secrets & Git Safety
- [x] Update `.gitignore` to explicitly ignore `key.properties`, `*.keystore`, `*.jks`, and `.env.*`
- [x] Create `android/key.properties.example` template for signing
- [x] Complete full repository secret audit (zero credentials in source)

## 3. Environment Separation & Configuration
- [x] Create `lib/core/app_environment.dart` with environment loader and runtime validation
- [x] Create `.env.development` template
- [x] Create `.env.staging` template
- [x] Create `.env.production` template

## 4. Automated CI/CD Pipeline
- [x] Create `.github/workflows/production_ci.yml` (Flutter analyze, test, and release builds)

## 5. Operations, Security Runbook & Store Readiness
- [x] Create `docs/PRODUCTION_RUNBOOK.md` (daily checks, incidents, key rotation, backup/restore)
- [x] Create `docs/STORE_READINESS.md` (Play Store checklist, Data Safety declaration, manual action boundaries)
- [x] Update `README.md` with complete production deployment guide

## 6. Verification & Final Gate
- [x] Run `flutter analyze` (0 issues)
- [x] Run `flutter test` (all 45 tests pass)
- [x] Update `walkthrough.md`
- [x] Compile Phase 7 Final Production Readiness Report (Sections A–AD) with GO / NO-GO recommendation
