#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/import_ntsd.py
python3 tools/inspect_original.py
swift build --package-path native -c release
binary_dir="$(swift build --package-path native -c release --show-bin-path)"
bundle='build/NTSD Native.app'
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/NTSDNative" "$bundle/Contents/MacOS/NTSDNative"
cp build/imported/game.json "$bundle/Contents/Resources/game.json"
python3 tools/package_assets.py
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>NTSDNative</string>
  <key>CFBundleIdentifier</key><string>local.ntsd.native</string>
  <key>CFBundleName</key><string>NTSD Native</string>
  <key>CFBundleDisplayName</key><string>NTSD Native</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
echo "Built: $PWD/$bundle"
