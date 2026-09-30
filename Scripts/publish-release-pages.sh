#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "usage: publish-release-pages.sh <tag> <commit> <dist-dir> <public-dmg>" >&2
    exit 64
fi

tag="$1"
commit="$2"
dist_dir="$(cd "$3" && pwd)"
public_dmg="$4"
script_dir="$(cd "$(dirname "$0")" && pwd)"
version="$("${script_dir}/verify-official-release-tag.sh" "$tag")"
evidence="${dist_dir}/release-evidence.json"
appcast="${dist_dir}/appcast.xml"

python3 - "$evidence" "$tag" "$commit" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    evidence = json.load(source)
if evidence["tag"] != sys.argv[2] or evidence["gitCommit"] != sys.argv[3]:
    raise SystemExit("release evidence tag or commit differs from requested publication")
PY
python3 "${script_dir}/verify-release-appcast.py" \
    --appcast "$appcast" --evidence "$evidence" --artifact "$public_dmg"

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
pages="${temporary}/pages"
if ssh_command="$(git config --local --get core.sshCommand)"; then
    export GIT_SSH_COMMAND="$ssh_command"
fi
git clone --quiet --branch gh-pages --single-branch "$(git remote get-url origin)" "$pages"
git -C "$pages" fetch --quiet origin "refs/tags/${tag}:refs/tags/${tag}"
if [[ "$(git -C "$pages" cat-file -t "refs/tags/${tag}")" != tag || \
      "$(git -C "$pages" rev-parse "refs/tags/${tag}^{commit}")" != "$commit" ]]; then
    echo "remote annotated tag ${tag} does not match ${commit}" >&2
    exit 1
fi

published_evidence="${pages}/releases/${tag}/release-evidence.json"
if [[ -e "$published_evidence" ]]; then
    if cmp -s "$evidence" "$published_evidence"; then
        echo "release evidence already published for ${tag}"
        exit 0
    fi
    echo "release evidence already exists with different bytes for ${tag}" >&2
    exit 1
fi

if [[ -f "${pages}/appcast.xml" ]] && ! cmp -s "$appcast" "${pages}/appcast.xml"; then
    python3 - "${pages}/appcast.xml" "$version" <<'PY'
import sys
import xml.etree.ElementTree as ET

sparkle_version = "{http://www.andymatuschak.org/xml-namespaces/sparkle}version"
current = ET.parse(sys.argv[1]).findtext(f"./channel/item/{sparkle_version}")
if current is None:
    raise SystemExit("published appcast has no version")
if tuple(map(int, current.split("."))) >= tuple(map(int, sys.argv[2].split("."))):
    raise SystemExit("published appcast is the same or a newer version with different bytes")
PY
fi

mkdir -p "$(dirname "$published_evidence")"
cp "$evidence" "$published_evidence"
cp "$appcast" "${pages}/appcast.xml"
touch "${pages}/.nojekyll"
git -C "$pages" config user.name "github-actions[bot]"
git -C "$pages" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$pages" add appcast.xml .nojekyll "releases/${tag}/release-evidence.json"
git -C "$pages" commit -m "docs(release): publish ${tag} feed and evidence"
git -C "$pages" push origin HEAD:gh-pages
