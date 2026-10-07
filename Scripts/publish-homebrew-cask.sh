#!/usr/bin/env bash
# Point the Homebrew cask in a checked-out tap at a verified public DMG.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 TAP_DIR VERSION PUBLIC_DMG" >&2
    exit 64
fi

tap="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"
version="$("${script_dir}/verify-official-release-tag.sh" "v$2")"
public_dmg="$3"
cask="${tap}/Casks/keyameleon.rb"
sha256="$(shasum -a 256 "$public_dmg" | cut -d ' ' -f 1)"

current_version="$(sed -nE 's/^  version "([^"]+)"$/\1/p' "$cask")"
current_sha256="$(sed -nE 's/^  sha256 "([0-9a-f]{64})"$/\1/p' "$cask")"
if [[ -z "$current_version" || -z "$current_sha256" ]]; then
    echo "cannot read version and sha256 from ${cask}" >&2
    exit 1
fi
if [[ "$current_version" == "$version" ]]; then
    if [[ "$current_sha256" == "$sha256" ]]; then
        echo "cask already points at ${version}"
        exit 0
    fi
    echo "cask ${version} already has a different sha256" >&2
    exit 1
fi
newest="$(printf '%s\n%s\n' "$current_version" "$version" | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)"
if [[ "$newest" != "$version" ]]; then
    echo "cask already points at newer version ${current_version}" >&2
    exit 1
fi

sed -i.bak -E \
    -e "s/^  version \"[^\"]+\"$/  version \"${version}\"/" \
    -e "s/^  sha256 \"[0-9a-f]{64}\"$/  sha256 \"${sha256}\"/" \
    "$cask"
rm "${cask}.bak"
git -C "$tap" config user.name "github-actions[bot]"
git -C "$tap" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$tap" add Casks/keyameleon.rb
git -C "$tap" commit -m "keyameleon ${version}"
git -C "$tap" push origin HEAD:main
