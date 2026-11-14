#!/usr/bin/env bash
# Builds a Developer ID–signed, notarized, stapled Margin.dmg.
# One-time setup (stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials margin-notary --apple-id <you@icloud.com> --team-id <TEAMID>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/release"
PROFILE="${NOTARY_PROFILE:-margin-notary}"
rm -rf "$OUT" && mkdir -p "$OUT"

"$ROOT/App/generate.sh" >/dev/null
xcodebuild -project "$ROOT/App/Margin.xcodeproj" -scheme Margin -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUT/Margin.xcarchive" -allowProvisioningUpdates archive | tail -1
xcodebuild -exportArchive -archivePath "$OUT/Margin.xcarchive" \
  -exportOptionsPlist "$ROOT/scripts/release/export-developer-id.plist" -exportPath "$OUT/export" -allowProvisioningUpdates | tail -1

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$OUT/export/Margin.app/Contents/Info.plist")"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$OUT/export/Margin.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/Margin-$VERSION.dmg"
hdiutil create -volname "Margin" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG" 2>/dev/null || true

if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl -a -t open --context context:primary-signature -vv "$DMG"
else
  echo "Skipped notarization: run the one-time 'notarytool store-credentials margin-notary' step first."
fi
echo "$DMG"
