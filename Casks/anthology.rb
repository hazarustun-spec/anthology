# Homebrew cask for Anthology. This repository doubles as its tap:
#   brew tap hazarustun-spec/anthology https://github.com/hazarustun-spec/anthology
#   brew trust hazarustun-spec/anthology
#   brew install --cask anthology
# Bump version + sha256 (shasum -a 256 build/release/Anthology.dmg) with every release.
cask "anthology" do
  version "0.2.1"
  sha256 "8ea1334707b289992bf39a2759ccdc1d788c0304d53d2094e7e5c1c925265afa"

  url "https://github.com/hazarustun-spec/anthology/releases/download/v#{version}/Anthology.dmg"
  name "Anthology"
  desc "Notes app your AI tools write into: Claude, Cursor, Codex, Gemini CLI"
  homepage "https://github.com/hazarustun-spec/anthology"

  depends_on macos: :tahoe

  app "Anthology.app"

  zap trash: [
    "~/Library/Application Support/Anthology",
    "~/Library/Preferences/com.hazarustun.margin.plist",
  ]
end
