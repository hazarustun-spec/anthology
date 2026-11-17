# Homebrew cask for Anthology. This repository doubles as its tap:
#   brew tap hazarustun-spec/anthology https://github.com/hazarustun-spec/anthology
#   brew install --cask anthology
cask "anthology" do
  version :latest
  sha256 :no_check

  url "https://github.com/hazarustun-spec/anthology/releases/latest/download/Anthology.dmg"
  name "Anthology"
  desc "Notes app your AI tools write into: Claude, Cursor, Codex, Gemini CLI"
  homepage "https://github.com/hazarustun-spec/anthology"

  depends_on macos: ">= :tahoe"

  app "Anthology.app"

  zap trash: [
    "~/Library/Application Support/Anthology",
    "~/Library/Preferences/com.hazarustun.margin.plist",
  ]
end
