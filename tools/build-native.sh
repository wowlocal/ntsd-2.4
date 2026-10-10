#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/import_ntsd.py
python3 tools/inspect_original.py
# Pin Xcode's toolchain; another swift earlier in PATH may not match the SDK.
swift=(xcrun --toolchain XcodeDefault swift)
# The shipping build drops Swift's dynamic exclusivity checks, as the APK does
# (the user's decision, CORE_REALTIME 4aa); test bundles keep them.
export NTSD_UNCHECKED_EXCLUSIVITY=1
"${swift[@]}" build --package-path native -c release
binary_dir="$("${swift[@]}" build --package-path native -c release --show-bin-path)"
bundle='build/NTSD Native.app'
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/NTSDNative" "$bundle/Contents/MacOS/NTSDNative"
cp build/imported/game.json "$bundle/Contents/Resources/game.json"
python3 tools/package_assets.py
# The original EXE's own icon (group 121) as the bundle icon.
python3 tools/make_app_icon.py "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe" "$bundle/Contents/Resources/AppIcon.icns"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>NTSDNative</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>local.ntsd.native</string>
  <key>CFBundleName</key><string>NTSD Native</string>
  <key>CFBundleDisplayName</key><string>NTSD Native</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.4.0</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
echo "Built: $PWD/$bundle"
