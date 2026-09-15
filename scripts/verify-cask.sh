#!/bin/sh
# Refuse to publish a cask that points at something users cannot install.
#
# The cask is a signpost: it tells brew which zip to download and what that
# zip's sha256 must be. Pushing it is what makes a release visible to everyone,
# and it is the one step in the release sequence that can succeed while the
# thing it points at does not exist.
#
# That is how 0.2.1 shipped broken. `gh release create` attaches assets in
# three separate API calls — create the release as a draft, upload the assets,
# then publish it — so a run interrupted partway leaves a draft with no asset,
# and a draft creates no git tag. The cask was pushed anyway, and because the
# download URL resolves through that tag and asset name, every `brew upgrade`
# 404'd for the next hour and a quarter.
#
# Why this lives here and not in mac_dir's scripts/release.sh: that script
# exits after stamping the cask and before the artifact is uploaded, so at the
# only moment it could look, the URL is legitimately still absent. A check
# there would fail every correct release. The check belongs where the signpost
# actually goes up, which is a push to this repository.
#
# Two things are verified, because checking only that the URL resolves would
# miss the other realistic failure:
#
#   1. the URL resolves          - draft release, missing or renamed asset, a
#                                  typo'd version
#   2. the bytes' sha256 matches - Xcode bundles are not byte-reproducible, so
#                                  rebuilding after the cask was stamped yields
#                                  a different checksum. The download then
#                                  succeeds and brew refuses to install it,
#                                  which is a different symptom with the same
#                                  outcome.
#
# Usage: scripts/verify-cask.sh            verify the working tree's cask
#        as .git/hooks/pre-push            verify the cask in each pushed commit
#
# Install the hook (hooks are not carried by a clone):
#        ln -sf ../../scripts/verify-cask.sh .git/hooks/pre-push

set -eu

CASK_PATH="Casks/macdir.rb"
RELEASE_REPO="illil/MacDir-releases"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() { echo; echo "verify-cask: $1" >&2; exit 1; }

# verify <cask-file> <label>
verify() {
    cask="$1"
    label="$2"

    version="$(sed -n 's/^  version "\(.*\)"$/\1/p' "$cask" | head -1)"
    sha_want="$(sed -n 's/^  sha256 "\(.*\)"$/\1/p' "$cask" | head -1)"
    url_raw="$(sed -n 's/^  url "\(.*\)"$/\1/p' "$cask" | head -1)"

    [ -n "$version" ]  || fail "no version stanza found in $label"
    [ -n "$sha_want" ] || fail "no sha256 stanza found in $label"
    [ -n "$url_raw" ]  || fail "no url stanza found in $label"

    # The cask writes its URL with Ruby interpolation, so expand it the same
    # way brew would rather than hardcoding the shape of the URL here.
    url="$(printf '%s' "$url_raw" | sed "s|#{version}|$version|g")"

    echo "    $label"
    echo "      version $version"
    echo "      url     $url"

    body="$WORK/asset"
    err="$WORK/curl.err"
    code="$(curl -sSL --retry 2 -o "$body" -w '%{http_code}' "$url" 2>"$err" || echo 000)"

    case "$code" in
        200) ;;
        000) fail "could not reach the release asset.
  $(cat "$err")
  If this machine is offline, publish from a connected one rather than skipping
  the check: an unverified cask 404s for every user, not just for you." ;;
        404) fail "the asset this cask points at does not exist (HTTP 404).
  $url

  An interrupted \`gh release create\` leaves the release as a DRAFT with no
  asset attached, and a draft creates no tag, so this URL cannot resolve.
  Check what is actually published, then finish it:

      gh release view   v$version --repo $RELEASE_REPO
      gh release upload v$version <the zip release.sh built> --repo $RELEASE_REPO
      gh release edit   v$version --repo $RELEASE_REPO --draft=false

  Upload the zip that release.sh produced, never a rebuild - see below." ;;
        *)   fail "unexpected HTTP $code from $url" ;;
    esac

    sha_got="$(shasum -a 256 "$body" | awk '{print $1}')"
    [ "$sha_got" = "$sha_want" ] || fail "sha256 mismatch - brew would reject this download.
  cask expects  $sha_want
  asset is      $sha_got

  The published asset is not the zip this cask was stamped from. Xcode bundles
  embed timestamps, so a rebuild is never byte-identical: upload the zip the
  release.sh run produced, or re-stamp the cask from what is published."

    echo "      asset present, sha256 matches"
}

# A pre-push hook is called with <remote-name> <remote-url> and fed the refs on
# stdin. Run by hand it gets neither, so that is the signal to check the
# working tree instead.
if [ $# -eq 2 ]; then
    # git runs hooks from the root of the working tree, which is the only
    # reliable way to find it here: $0 is .git/hooks/pre-push, and since that is
    # a symlink to this file, deriving the root from $0 lands in .git instead.
    REPO="$(pwd)"

    echo "verify-cask: checking the cask being pushed to $1"
    checked=0
    while read -r _local_ref local_sha _remote_ref remote_sha; do
        # An all-zero local sha is a branch deletion: nothing to verify.
        case "$local_sha" in *[!0]*) ;; *) continue ;; esac

        # Other branches or repos may not carry a cask at all.
        git -C "$REPO" cat-file -e "$local_sha:$CASK_PATH" 2>/dev/null || continue

        short="$(printf '%s' "$local_sha" | cut -c1-7)"

        # A README-only push must not pay for a multi-megabyte download, or the
        # habit becomes --no-verify. The risky act is changing the signpost, so
        # skip when the cask is identical to what the remote already has.
        case "$remote_sha" in
            *[!0]*)
                if git -C "$REPO" diff --quiet "$remote_sha" "$local_sha" -- "$CASK_PATH" 2>/dev/null; then
                    echo "    $CASK_PATH unchanged in $short - nothing to verify"
                    continue
                fi ;;
        esac

        git -C "$REPO" show "$local_sha:$CASK_PATH" > "$WORK/cask.rb"
        verify "$WORK/cask.rb" "$CASK_PATH at $short"
        checked=$((checked + 1))
    done

    [ "$checked" -gt 0 ] || echo "    no cask change in this push"
else
    # Run by hand, $0 is the real file rather than the hook symlink, so the repo
    # root is one level up from it — and that holds from any cwd.
    REPO="$(cd "$(dirname "$0")/.." && pwd)"

    echo "verify-cask: checking the working tree"
    verify "$REPO/$CASK_PATH" "$CASK_PATH (working tree)"
fi

echo "verify-cask: ok"
