#!/bin/bash
# Creates the Android release signing key once, outside the repository:
#   ~/.config/ntsd/android-release.p12 (PKCS#12, alias "ntsd", RSA 4096, 30 years)
# Its password is random and lives only in the login Keychain (service
# ntsd-android-release-keystore, account ntsd); it is never written to a file
# or printed. android_app.py --release reads it from there.
# Keep a backup of the keystore: without it no update of a published APK can
# be signed with the same key.
set -euo pipefail
KEY="$HOME/.config/ntsd/android-release.p12"; SERVICE=ntsd-android-release-keystore
if [ -f "$KEY" ]; then echo "exists: $KEY"; exit 0; fi
if security find-generic-password -s "$SERVICE" -a ntsd >/dev/null 2>&1; then
  echo "a Keychain password for $SERVICE exists but no keystore; refusing to overwrite either" >&2; exit 1
fi
mkdir -p "$(dirname "$KEY")"; chmod 700 "$(dirname "$KEY")"
NTSD_KS_PASS=$(openssl rand -base64 30 | tr -d '\n')
export NTSD_KS_PASS
security add-generic-password -s "$SERVICE" -a ntsd -l "NTSD Android release keystore" -w "$NTSD_KS_PASS"
keytool -genkeypair -storetype PKCS12 -keystore "$KEY" -alias ntsd -keyalg RSA -keysize 4096 -validity 10950 \
  -storepass:env NTSD_KS_PASS -keypass:env NTSD_KS_PASS -dname "CN=NTSD Native port" >/dev/null 2>&1
chmod 600 "$KEY"
unset NTSD_KS_PASS
echo "created: $KEY"
