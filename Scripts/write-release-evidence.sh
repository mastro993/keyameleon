#!/usr/bin/env bash
# Writes release-evidence.json binding the Official Release DMG SHA-256 to its source tag.
# Field names match KeyameleonReleaseEvidence Codable keys.
set -euo pipefail

usage() {
    echo "usage: write-release-evidence.sh --tag <vX.Y.Z> --commit <sha> --artifact <dmg> --output <path>" >&2
    exit 64
}

tag=""
commit=""
artifact=""
output=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            tag="${2:-}"
            shift 2
            ;;
        --commit)
            commit="${2:-}"
            shift 2
            ;;
        --artifact)
            artifact="${2:-}"
            shift 2
            ;;
        --output)
            output="${2:-}"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$tag" || -z "$commit" || -z "$artifact" || -z "$output" ]]; then
    usage
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
version="$("${script_dir}/verify-official-release-tag.sh" "$tag")"

if [[ ! -f "$artifact" ]]; then
    echo "artifact not found: ${artifact}" >&2
    exit 1
fi

if [[ -z "$commit" ]]; then
    echo "git commit is required" >&2
    exit 1
fi

sha256="$(shasum -a 256 "$artifact" | awk '{print $1}')"
archive_name="Keyameleon-${version}.dmg"
if [[ "$(basename "$artifact")" != "$archive_name" ]]; then
    echo "artifact must be named ${archive_name}" >&2
    exit 1
fi
feed_url="https://mastro993.github.io/Keyameleon/appcast.xml"

mkdir -p "$(dirname "$output")"

python3 - "$output" "$tag" "$version" "$commit" "$archive_name" "$sha256" "$feed_url" <<'PY'
import json
import sys

(
    path,
    tag,
    version,
    commit,
    archive_name,
    sha256,
    feed_url,
) = sys.argv[1:8]

evidence = {
    "product": "Keyameleon",
    "licenseSPDXIdentifier": "GPL-3.0-only",
    "tag": tag,
    "semanticVersion": version,
    "gitCommit": commit,
    "artifactFileName": archive_name,
    "artifactSHA256": sha256,
    "appcastFileName": "appcast.xml",
    "feedURLString": feed_url,
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(evidence, handle, indent=2, sort_keys=True)
    handle.write("\n")
print(path)
PY

printf '%s\n' "$sha256"
