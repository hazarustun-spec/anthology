#!/bin/sh
# Anthology one-line installer for macOS:
#   curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh
# Downloads the latest notarized release, checks its signature, puts Anthology.app in /Applications and opens it.
# Set ANTHOLOGY_DMG=/path/to/Anthology.dmg to install from a local file instead.
#
# Everything runs inside main(), so a download cut off halfway can't execute a partial script.

main() {
  set -eu

  REPO="${ANTHOLOGY_REPO:-hazarustun-spec/anthology}"
  URL="https://github.com/$REPO/releases/latest/download/Anthology.dmg"
  APP="${ANTHOLOGY_INSTALL_DIR:-/Applications}/Anthology.app"
  TEAM_ID="4MBWF4RGV7"   # Developer ID team that signs every Anthology release

  say() { printf '\033[1m%s\033[0m\n' "$*"; }
  fail() { printf 'Anthology install failed: %s\n' "$*" >&2; exit 1; }

  [ "$(uname -s)" = "Darwin" ] || fail "Anthology runs on macOS."
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "$major" -ge 26 ] || fail "macOS 26 or newer is required (this Mac has $(sw_vers -productVersion))."

  tmp="$(mktemp -d)"
  mnt="$tmp/mnt"
  cleanup() { hdiutil detach -quiet "$mnt" 2>/dev/null || true; rm -rf "$tmp"; }
  trap cleanup EXIT

  if [ -n "${ANTHOLOGY_DMG:-}" ]; then
    cp "$ANTHOLOGY_DMG" "$tmp/Anthology.dmg"
  else
    say "Downloading Anthology..."
    curl -fL --proto '=https' --tlsv1.2 --progress-bar -o "$tmp/Anthology.dmg" "$URL" || fail "could not download $URL"
  fi

  mkdir -p "$mnt"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$tmp/Anthology.dmg" || fail "could not open the disk image"
  src="$mnt/Anthology.app"
  [ -d "$src" ] || fail "the disk image does not contain Anthology.app"

  # Refuse anything that isn't Anthology signed by its developer and notarized by Apple.
  say "Checking the signature..."
  codesign --verify --deep --strict "$src" 2>/dev/null || fail "Anthology.app's signature is broken. Nothing was installed."
  team="$(codesign -dv "$src" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  [ "$team" = "$TEAM_ID" ] || fail "Anthology.app is signed by an unexpected developer ($team). Nothing was installed."
  spctl --assess --type execute "$src" 2>/dev/null || fail "macOS Gatekeeper rejected Anthology.app. Nothing was installed."

  # Quit a running copy so it can be replaced.
  osascript -e 'tell application id "com.hazarustun.margin" to quit' >/dev/null 2>&1 || true
  sleep 1

  say "Installing to ${APP}..."
  if [ -w "$(dirname "$APP")" ]; then
    rm -rf "$APP" && ditto "$src" "$APP"
  else
    sudo rm -rf "$APP" && sudo ditto "$src" "$APP"
  fi

  say "Done. Opening Anthology — it will offer to connect Claude and your other AI tools."
  open "$APP"
}

main "$@"
