#!/bin/sh
# Builds Clipstack.app (universal: Apple silicon and Intel) into ./build.
#   ./scripts/build-app.sh            build only
#   ./scripts/build-app.sh --install  also copy it to /Applications and open it
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
APP=build/Clipstack.app

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Clipstack"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Clipstack"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Clipstack</string>
  <key>CFBundleDisplayName</key><string>Clipstack</string>
  <key>CFBundleIdentifier</key><string>io.github.cipherhex09.clipstack</string>
  <key>CFBundleExecutable</key><string>Clipstack</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc signature. Good enough to run locally; see the README for Gatekeeper.
codesign --force --sign - --options runtime "$APP"
echo "built $APP"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'quit app "Clipstack"' 2>/dev/null || true
  rm -rf /Applications/Clipstack.app
  cp -R "$APP" /Applications/
  open /Applications/Clipstack.app
  echo "installed to /Applications"
fi
