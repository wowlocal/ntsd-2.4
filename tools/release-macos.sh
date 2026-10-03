#!/usr/bin/env bash
# Signed, notarized and stapled release of "build/NTSD Native.app" (built by
# tools/build-native.sh): the app is signed with Developer ID and the hardened
# runtime, notarized as a zip and stapled; then a DMG of the stapled app is
# signed, notarized and stapled, and Gatekeeper must accept it as a
# "Notarized Developer ID". Output: build/release/NTSD-Native-<version>.dmg and
# its .sha256.
#
# usage: tools/release-macos.sh [SIGNING_IDENTITY] [NOTARY_PROFILE]
# The notary profile is a `xcrun notarytool store-credentials` keychain item;
# no password is read or written here.
set -euo pipefail
cd "$(dirname "$0")/.."
identity="${1:-Developer ID Application: Misha Kharytonchyk (H8QG3CBM96)}"
profile="${2:-codex-notary}"
app='build/NTSD Native.app'
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
out='build/release'
name="NTSD-Native-$version"
mkdir -p "$out"
accepted() { python3 -c 'import json,sys; s=json.load(open(sys.argv[1])).get("status"); print("notary status:", s); sys.exit(s != "Accepted")' "$1"; }

echo "== sign $app ($version)"
# The bundle's only code is its main executable; everything else is data.
machos="$(find "$app" -type f -exec file {} + | grep 'Mach-O' | cut -d: -f1)"
echo "   Mach-O: $machos"
[[ "$machos" == "$app/Contents/MacOS/NTSDNative" ]] || { echo 'unexpected nested code'; exit 1; }
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

echo "== notarize the app"
ditto -c -k --keepParent "$app" "$out/$name.app.zip"
xcrun notarytool submit "$out/$name.app.zip" --keychain-profile "$profile" --wait --output-format json | tee "$out/$name.app.notary.json"
accepted "$out/$name.app.notary.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl -a -t exec -vv "$app" 2>&1 | tee "$out/$name.app.spctl.txt"
grep -q 'source=Notarized Developer ID' "$out/$name.app.spctl.txt"
rm "$out/$name.app.zip"

echo "== DMG"
stage="$(mktemp -d)"
ditto "$app" "$stage/NTSD Native.app"
ln -s /Applications "$stage/Applications"
rm -f "$out/$name.dmg"
hdiutil create -volname "NTSD Native $version" -srcfolder "$stage" -fs HFS+ -format ULFO -ov "$out/$name.dmg"
rm -rf "$stage"
codesign --force --timestamp --sign "$identity" "$out/$name.dmg"
codesign --verify --verbose=2 "$out/$name.dmg"

echo "== notarize the DMG"
xcrun notarytool submit "$out/$name.dmg" --keychain-profile "$profile" --wait --output-format json | tee "$out/$name.dmg.notary.json"
accepted "$out/$name.dmg.notary.json"
xcrun stapler staple "$out/$name.dmg"
xcrun stapler validate "$out/$name.dmg"
spctl -a -t open --context context:primary-signature -vv "$out/$name.dmg" 2>&1 | tee "$out/$name.dmg.spctl.txt"
grep -q 'accepted' "$out/$name.dmg.spctl.txt" && grep -q 'source=Notarized Developer ID' "$out/$name.dmg.spctl.txt"

# The stapled ticket changes the file: the checksum comes last.
(cd "$out" && shasum -a 256 "$name.dmg" | tee "$name.dmg.sha256")
echo "Release: $PWD/$out/$name.dmg"
