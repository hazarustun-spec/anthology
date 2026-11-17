# Homebrew cask for Anthology. This repository doubles as its tap:
#   brew tap hazarustun-spec/anthology https://github.com/hazarustun-spec/anthology
#   brew trust hazarustun-spec/anthology
#   brew install --cask anthology
# Bump version + sha256 (shasum -a 256 build/release/Anthology.dmg) with every release.
cask "anthology" do
  version "0.2.0"
  sha256 "b4759b780ddc3f6e761604c72ebc64a8b61ab41cb081b2cd590d01eed75264cf"

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
