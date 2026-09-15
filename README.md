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
  line is harmless. Trust is recorded by name, so this is a one-time step — it
  survives every later release of the cask.
- **`xattr`** — MacDir is signed with a self-signed certificate rather than a
  Developer ID, so it is not notarized by Apple. Homebrew marks every download as
  quarantined and Gatekeeper refuses to launch an unnotarized quarantined app.
  `brew install` prints this same reminder at the end. (The old
  `brew install --no-quarantine` shortcut was removed in Homebrew 6.0.)

Both lines go away once MacDir ships with Developer ID signing and notarization.

## Update

```sh
brew update && brew upgrade --cask macdir
```

`brew update` has to come first: it re-fetches this tap. Without it Homebrew
still sees the cask revision it cloned last time and reports nothing to upgrade,
however many releases have shipped since.

If you installed MacDir before Homebrew 6.0, you have no trust record yet, and
an upgrade fails the same way a fresh install does — trust is checked when the
cask is *read*, not when it is installed. Run this once:

```sh
brew update && brew trust --tap illil/macdir && brew upgrade --cask macdir
```

Then clear the quarantine attribute again — an upgrade downloads a fresh zip and
Homebrew quarantines it exactly as on first install:

```sh
xattr -dr com.apple.quarantine /Applications/MacDir.app
```

Your preferences, favorites, and notes are untouched by an upgrade. Because
every build is signed with the same certificate, macOS also keeps the file-access
permissions you already granted.

## Uninstall

```sh
brew uninstall --cask macdir
```

Add `--zap` to also delete MacDir's preferences, saved window state, and
`~/Library/Application Support/MacDir` — **that directory holds notes you wrote
in the app**, so plain `brew uninstall` is the right choice unless you mean to
discard them.

## Releasing (maintainer)

Three repositories are involved:

| Repository | Visibility | Holds |
|---|---|---|
| `illil/MacDir` | private | source |
| `illil/MacDir-releases` | **public** | release zips only — a private repo's assets 404 for users |
| `illil/homebrew-macdir` | **public** | this cask |

Releases are cut from the source repository:

```sh
scripts/release.sh <version>
```

That script builds, signs, packages, verifies the signature survives the zip
round trip, and stamps the new `version` and `sha256` into `Casks/macdir.rb`
here. It deliberately publishes nothing — it prints the `gh release create` and
`git push` commands to run afterwards, so going live stays an explicit act.

### The pre-push check

Pushing the cask is what makes a release visible to every user, and it is the
one step that can succeed while the artifact it points at does not exist. 0.2.1
shipped that way: `gh release create` attaches assets in three separate API
calls — create the release as a draft, upload, publish — so an interrupted run
leaves a draft with no asset and no tag. The cask went out pointing at it, and
`brew upgrade` returned 404 for the next hour and a quarter.

`scripts/verify-cask.sh` closes that gap. Install it once per clone, since git
hooks are not cloned:

```sh
ln -sf ../../scripts/verify-cask.sh .git/hooks/pre-push
```

Before any push that changes `Casks/macdir.rb` it downloads what the cask points
at and checks two things:

- **the URL resolves** — catches a draft release, a missing or renamed asset, a
  typo'd version
- **the bytes' sha256 matches the cask** — catches a rebuild after stamping.
  Xcode bundles embed timestamps, so a rebuild is never byte-identical; the
  download then succeeds and `brew` refuses to install it

A push that leaves the cask alone skips the download, so README edits stay
instant. Run it against the working tree with no arguments:

```sh
scripts/verify-cask.sh
```

The check cannot live in mac_dir's `scripts/release.sh`: that script exits after
stamping the cask and before the artifact is uploaded, so at the only moment it
could look, the URL is legitimately still absent.
