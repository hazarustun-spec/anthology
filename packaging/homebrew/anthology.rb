# Homebrew cask for Anthology. Lives in the tap repo hazarustun-spec/homebrew-anthology as Casks/anthology.rb:
#   brew install --cask hazarustun-spec/anthology/anthology
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
