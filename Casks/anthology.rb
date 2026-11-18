# Homebrew cask for Anthology. This repository doubles as its tap:
#   brew tap hazarustun-spec/anthology https://github.com/hazarustun-spec/anthology
#   brew trust hazarustun-spec/anthology
#   brew install --cask anthology
# Bump version + sha256 (shasum -a 256 build/release/Anthology.dmg) with every release.
cask "anthology" do
  version "0.2.2"
  sha256 "524fe434b0550d497bbc11ea8e47002bbd22cbc7600ec55f01bc2d142a702fdf"

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
