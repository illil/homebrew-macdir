# homebrew-macdir

Homebrew tap for [MacDir](https://github.com/illil/MacDir), a keyboard-first
dual-pane file manager for macOS.

## Install

```sh
brew tap illil/macdir
brew install --cask macdir
xattr -dr com.apple.quarantine /Applications/MacDir.app
```

The third line is required because MacDir is signed with a self-signed
certificate rather than a Developer ID, so it is not notarized by Apple.
Homebrew marks every download as quarantined and Gatekeeper refuses to launch
an unnotarized quarantined app. `brew install` prints this same reminder.

If you run Homebrew with `HOMEBREW_REQUIRE_TAP_TRUST` set, trust the tap first:

```sh
brew trust --tap illil/macdir
```

Requires macOS 14 (Sonoma) or later.

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
