#!/usr/bin/env bash
# Generates Margin.xcodeproj with the ids from Local.xcconfig (see Local.sample.xcconfig).
set -euo pipefail
cd "$(dirname "$0")"
[ -f Local.xcconfig ] || { echo "Create App/Local.xcconfig from Local.sample.xcconfig first."; exit 1; }
MARGIN_BUNDLE_ID="$(sed -n 's/^MARGIN_BUNDLE_ID *= *//p' Local.xcconfig | tr -d '[:space:]')"
export MARGIN_BUNDLE_ID
xcodegen generate --spec project.yml
