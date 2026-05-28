#!/bin/bash
# Builds PortBar.app — a self-contained menu bar app bundle.
#
# Usage:
#   ./build-app.sh                       build to ./build/PortBar.app
#   ./build-app.sh --install             …and copy to /Applications
#   ./build-app.sh --sign "Developer ID Application: Name (TEAMID)"
#                                        sign with a specific identity
#
# Signing: if --sign isn't given, the script auto-detects a "Developer ID
# Application" identity (best — distributable + notarizable). If none exists it
# falls back to any "Apple Development" identity (runs locally only), and
# finally to an ad-hoc signature. See README "Sharing / distribution".
set -euo pipefail
cd "$(dirname "$0")"

APP="PortBar"
BUNDLE_ID="io.github.abhiraa.PortBar"
OUT="build/$APP.app"
INSTALL=false
IDENTITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) INSTALL=true; shift ;;
    --sign)    IDENTITY="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

# Keep the dev build out of Spotlight so its contents aren't indexed.
mkdir -p build
touch build/.metadata_never_index
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "▸ Compiling release binary…"
swift build -c release >/dev/null

echo "▸ Generating app icon…"
swift scripts/make-icon.swift >/dev/null
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns

echo "▸ Assembling ${OUT}…"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/$APP" "$OUT/Contents/MacOS/$APP"
cp build/AppIcon.icns "$OUT/Contents/Resources/AppIcon.icns"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# --- Signing -----------------------------------------------------------------
# Resolve an identity if not supplied explicitly.
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(echo "$IDENTITIES" | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/' || true)
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(echo "$IDENTITIES" | grep "Apple Development" | head -1 | sed -E 's/.*"(.*)"/\1/' || true)
fi

if [[ -n "$IDENTITY" ]]; then
  echo "▸ Signing with: $IDENTITY"
  # Hardened runtime + secure timestamp (required for notarization).
  codesign --force --options runtime --timestamp \
           --sign "$IDENTITY" "$OUT" 2>/dev/null \
    || codesign --force --options runtime --sign "$IDENTITY" "$OUT"
  if [[ "$IDENTITY" == *"Developer ID"* ]]; then
    echo "  ✓ Signed for distribution. Next: notarize (see README)."
  else
    echo "  ⚠ Signed with a development cert — runs on THIS Mac only."
    echo "    To share with others you need a Developer ID cert + notarization."
  fi
else
  echo "▸ No signing identity found — using ad-hoc signature (local only)."
  codesign --force --sign - "$OUT" >/dev/null 2>&1 || true
fi

echo "✓ Built $OUT"

if [[ "$INSTALL" == true ]]; then
  echo "▸ Installing to /Applications…"
  rm -rf "/Applications/$APP.app"
  cp -R "$OUT" "/Applications/$APP.app"
  echo "✓ Installed. Launch from Spotlight or: open \"/Applications/$APP.app\""
fi

# Unregister the staging copy from Launch Services so it never shows up as a
# duplicate in Launchpad/Spotlight. The file stays on disk (for zipping /
# notarizing); the canonical app is the one you install to /Applications.
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -u "$PWD/$OUT" >/dev/null 2>&1 || true
fi
