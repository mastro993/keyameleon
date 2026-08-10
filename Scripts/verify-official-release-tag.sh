#!/usr/bin/env bash
# Validates that a ref is an Official Release tag: vMAJOR.MINOR.PATCH (SemVer core only).
# Portable bash so Ubuntu CI and macOS both run it.
set -euo pipefail

tag="${1:-}"
if [[ -z "$tag" ]]; then
    echo "usage: verify-official-release-tag.sh <tag>" >&2
    exit 64
fi

# Keep in lockstep with KeyameleonReleasePolicy.semanticVersion(fromOfficialReleaseTag:).
if [[ ! "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "not an Official Release tag: ${tag}" >&2
    echo "expected: vMAJOR.MINOR.PATCH (Semantic Versioning core only)" >&2
    exit 1
fi

version="${tag#v}"
printf '%s\n' "$version"
