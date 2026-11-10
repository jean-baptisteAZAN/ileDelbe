cask "iledelbe" do
  version "0.2.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_SH"

  url "https://github.com/jean-baptisteAZAN/ileDelbe/releases/download/v#{version}/ileDelbe-#{version}.zip"
  name "ileDelbe"
  desc "Dynamic Island-style hub for the MacBook notch"
  homepage "https://github.com/jean-baptisteAZAN/ileDelbe"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "IleDelbe.app"

  uninstall quit: "io.github.ileDelbe"

  zap trash: "~/Library/Preferences/io.github.ileDelbe.plist"
end
