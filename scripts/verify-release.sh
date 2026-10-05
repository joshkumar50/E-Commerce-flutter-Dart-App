#!/bin/bash
# Verify release APK doesn't contain secrets
set -e

APK_PATH=$1

if [ -z "$APK_PATH" ]; then
  echo "Usage: $0 path/to/app-release.apk"
  exit 1
fi

echo "Verifying $APK_PATH for leaked secrets..."
TMP_DIR=$(mktemp -d)
unzip -q "$APK_PATH" -d "$TMP_DIR"

if grep -rIn "eyJhbGciOiJIUzI1Ni\|-----BEGIN\|service_role" "$TMP_DIR/assets/flutter_assets" 2>/dev/null; then
  echo "FAIL: Leaked secret detected in flutter_assets!"
  rm -rf "$TMP_DIR"
  exit 1
else
  echo "PASS: No secrets detected in release artifacts."
  rm -rf "$TMP_DIR"
  exit 0
fi
