cask "macdir" do
  # version/sha256 are stamped by mac_dir's scripts/release.sh — edit through a
  # release, not by hand, so the checksum can never drift from the artifact.
  version "0.1.0"
  sha256 "d384709aa122a6bd844c6cefff1eab90547df3e8ef88e5ff83061d1a11f8e3d3"

  url "https://github.com/illil/MacDir/releases/download/v#{version}/MacDir-#{version}.zip"
  name "MacDir"
  desc "Keyboard-first dual-pane file manager"
  homepage "https://github.com/illil/MacDir"

  livecheck do
    url :url
    strategy :github_latest
  end

  # MACOSX_DEPLOYMENT_TARGET = 14.0 in MacDir.xcodeproj. A bare symbol already
  # means ">=" (Cask::DSL::DependsOn#macos= parses with comparator ">="); the
  # explicit ">= :sonoma" string form is deprecated as of Homebrew 6.0.
  depends_on macos: :sonoma

  app "MacDir.app"

  # `brew uninstall --zap` only. Application Support holds user-authored notes
  # (MacDir/NotesStore.swift), so zapping is genuinely destructive — plain
  # `brew uninstall` leaves it alone.
  zap trash: [
    "~/Library/Application Support/MacDir",
    "~/Library/Preferences/com.illil.macdir.plist",
    "~/Library/Saved Application State/com.illil.macdir.savedState",
  ]

  # MacDir is signed with a self-signed certificate, not a Developer ID, so it
  # is not notarized. Homebrew quarantines every download and Gatekeeper blocks
  # the first launch until the attribute is cleared. Stating it here means brew
  # prints the fix at install time instead of the user hitting a dead end.
  # Drop this stanza once Developer ID + notarization ship.
  caveats <<~EOS
    MacDir is not notarized yet, so macOS blocks the first launch.
    Clear the quarantine attribute once:

      xattr -dr com.apple.quarantine /Applications/MacDir.app
  EOS
end
