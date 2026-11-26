#!/usr/bin/env bash
# Makes a fixture release for the tests of this action: the archive of the runner's platform, named
# and laid out as a release of nWidart/mortise names and lays it out, and its sums file.
#
#   tests/make-fixture-release.sh <mortise binary> <folder>
#
# It writes <folder>/<tag>/ and prints the tag, read from `mortise --version`.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <mortise binary> <folder>" >&2
  exit 2
fi
built=$1
folder=$2

printed=$("$built" --version)
tag="v${printed#mortise }"

binary=mortise
case "$RUNNER_OS/$RUNNER_ARCH" in
  Linux/X64) platform=linux-x86_64.tar.gz ;;
  Linux/ARM64) platform=linux-arm64.tar.gz ;;
  macOS/ARM64) platform=macos-arm64.zip ;;
  Windows/X64)
    platform=windows-x64.zip
    binary=mortise.exe
    ;;
  *)
    echo "No fixture for $RUNNER_OS on $RUNNER_ARCH." >&2
    exit 1
    ;;
esac
archive="mortise-$tag-$platform"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "$built" "$stage/$binary"
echo 'MIT License' > "$stage/LICENSE"
echo '# Third-party licences' > "$stage/THIRD-PARTY.md"

release="$folder/$tag"
mkdir -p "$release"
out=$(cd "$release" && pwd)/$archive
case "$archive" in
  *.tar.gz) tar -czf "$out" -C "$stage" "$binary" LICENSE THIRD-PARTY.md ;;
  *.zip)
    if command -v zip > /dev/null; then
      (cd "$stage" && zip -q "$out" "$binary" LICENSE THIRD-PARTY.md)
    else
      (cd "$stage" && 7z a -tzip -bso0 -bsp0 "$(cygpath -w "$out")" "$binary" LICENSE THIRD-PARTY.md)
    fi
    ;;
esac

# A release lists its installers too, so the sums file has another line before the archive's.
(
  cd "$release"
  if command -v sha256sum > /dev/null; then sum=(sha256sum); else sum=(shasum -a 256); fi
  {
    echo "0000000000000000000000000000000000000000000000000000000000000000  Mortise-$tag-macos-arm64.dmg"
    "${sum[@]}" "$archive"
  } > "Mortise-$tag-SHA256SUMS.txt"
)
echo "$tag"
