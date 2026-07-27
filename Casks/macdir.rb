cask "macdir" do
  # version/sha256 are stamped by mac_dir's scripts/release.sh — edit through a
  # release, not by hand, so the checksum can never drift from the artifact.
  version "0.1.0"
  sha256 "51b91b0de9a8f1fc36b579e7296daa2c4a0ffc862d6a3e87c068f6db4463210d"

  # MacDir's source repo (illil/MacDir) is private, so its release assets are not
  # downloadable without auth. Binaries ship from a public releases-only repo
  # instead; homepage points there too so it resolves for users and so the url's
  # host matches the homepage's (which is what lets audit skip `verified:`).
  url "https://github.com/illil/MacDir-releases/releases/download/v#{version}/MacDir-#{version}.zip"
  name "MacDir"
  desc "Keyboard-first dual-pane file manager"
  homepage "https://github.com/illil/MacDir-releases"

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
