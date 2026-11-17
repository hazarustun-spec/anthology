#!/bin/sh
# Anthology one-line installer for macOS:
#   curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh
# Downloads the latest notarized release, puts Anthology.app in /Applications and opens it.
# Set ANTHOLOGY_DMG=/path/to/Anthology.dmg to install from a local file instead.
set -eu

REPO="${ANTHOLOGY_REPO:-hazarustun-spec/anthology}"
URL="https://github.com/$REPO/releases/latest/download/Anthology.dmg"
APP="${ANTHOLOGY_INSTALL_DIR:-/Applications}/Anthology.app"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf 'Anthology install failed: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Anthology runs on macOS (and iPhone via the App Store)."
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || fail "macOS 26 or newer is required (this Mac has $(sw_vers -productVersion))."

tmp="$(mktemp -d)"
mnt="$tmp/mnt"
cleanup() { hdiutil detach -quiet "$mnt" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

if [ -n "${ANTHOLOGY_DMG:-}" ]; then
  cp "$ANTHOLOGY_DMG" "$tmp/Anthology.dmg"
else
  say "Downloading Anthology…"
  curl -fL --progress-bar -o "$tmp/Anthology.dmg" "$URL" || fail "could not download $URL"
fi

mkdir -p "$mnt"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$tmp/Anthology.dmg" || fail "could not open the disk image"
[ -d "$mnt/Anthology.app" ] || fail "the disk image does not contain Anthology.app"

# Quit a running copy so it can be replaced.
osascript -e 'tell application "Anthology" to quit' >/dev/null 2>&1 || true
sleep 1

say "Installing to $APP…"
if [ -w "$(dirname "$APP")" ]; then
  rm -rf "$APP" && ditto "$mnt/Anthology.app" "$APP"
else
  sudo rm -rf "$APP" && sudo ditto "$mnt/Anthology.app" "$APP"
fi

say "Done. Opening Anthology — it will offer to connect Claude and your other AI tools."
open "$APP"
