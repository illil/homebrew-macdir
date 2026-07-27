# homebrew-macdir

Homebrew tap for [MacDir](https://github.com/illil/MacDir), a keyboard-first
dual-pane file manager for macOS.

## Install

```sh
brew tap illil/macdir
brew trust --tap illil/macdir
brew install --cask macdir
xattr -dr com.apple.quarantine /Applications/MacDir.app
```

Requires macOS 14 (Sonoma) or later.

Why four lines and not two:

- **`brew trust`** — since Homebrew 6.0, `HOMEBREW_REQUIRE_TAP_TRUST` defaults to
  on, so Homebrew refuses to load a cask from a third-party tap until you say you
  trust it. Without this line `brew install` fails with
  `Refusing to load cask ... from untrusted tap`. On Homebrew 5.x and earlier the
  line is harmless.
- **`xattr`** — MacDir is signed with a self-signed certificate rather than a
  Developer ID, so it is not notarized by Apple. Homebrew marks every download as
  quarantined and Gatekeeper refuses to launch an unnotarized quarantined app.
  `brew install` prints this same reminder at the end. (The old
  `brew install --no-quarantine` shortcut was removed in Homebrew 6.0.)

Both lines go away once MacDir ships with Developer ID signing and notarization.

## Update

```sh
brew upgrade --cask macdir
```

## Uninstall

```sh
brew uninstall --cask macdir
```

Add `--zap` to also delete MacDir's preferences, saved window state, and
`~/Library/Application Support/MacDir` — **that directory holds notes you wrote
in the app**, so plain `brew uninstall` is the right choice unless you mean to
discard them.

## Releasing (maintainer)

This repository holds only the cask. Releases are cut from the app repository:

```sh
cd ~/Projects/illil/mac_dir && scripts/release.sh <version>
```

That script builds, signs, packages, verifies, and stamps the new `version` and
`sha256` into `Casks/macdir.rb` here. It deliberately does not publish anything;
it prints the `gh release create` and `git push` commands to run afterwards.
