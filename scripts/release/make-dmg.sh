#!/usr/bin/env bash
# Builds a Developer ID–signed, notarized, stapled Anthology.dmg.
# One-time setup (stores App Store Connect API key credentials in your keychain):
#   xcrun notarytool store-credentials margin-notary --key <AuthKey.p8> --key-id <KEYID> --issuer <ISSUER>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/release"
PROFILE="${NOTARY_PROFILE:-margin-notary}"
rm -rf "$OUT" && mkdir -p "$OUT"

"$ROOT/App/generate.sh" >/dev/null
xcodebuild -project "$ROOT/App/Margin.xcodeproj" -scheme Margin -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUT/Anthology.xcarchive" -allowProvisioningUpdates archive | tail -1
xcodebuild -exportArchive -archivePath "$OUT/Anthology.xcarchive" \
  -exportOptionsPlist "$ROOT/scripts/release/export-developer-id.plist" -exportPath "$OUT/export" -allowProvisioningUpdates | tail -1

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$OUT/export/Anthology.app/Contents/Info.plist")"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$OUT/export/Anthology.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/Anthology-$VERSION.dmg"
hdiutil create -volname "Anthology" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG" 2>/dev/null || true

if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  # The DMG itself is unsigned when no local Developer ID cert exists (export uses cloud signing);
  # Gatekeeper judges the notarized app inside, so assess that instead.
  spctl -a -t exec -vv "$OUT/export/Anthology.app"
else
  echo "Skipped notarization: run the one-time 'notarytool store-credentials margin-notary' step first."
fi
cp "$DMG" "$OUT/Anthology.dmg"   # stable name for releases/latest/download/Anthology.dmg
echo "$DMG"
