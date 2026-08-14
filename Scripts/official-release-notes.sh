#!/usr/bin/env bash
# Prints the Changes body for an Official Release at HEAD (or the given rev).
# Previous Official Release = highest SemVer Official Release tag that is an
# ancestor of that rev. Subjects only. No merge commits. No authors.
set -euo pipefail

head_rev="${1:-HEAD}"
head_sha="$(git rev-parse "${head_rev}^{commit}")"
script_dir="$(cd "$(dirname "$0")" && pwd)"

previous=""
while IFS= read -r tag; do
    [[ -n "$tag" ]] || continue
    if ! "${script_dir}/verify-official-release-tag.sh" "$tag" >/dev/null 2>&1; then
        continue
    fi
    if git merge-base --is-ancestor "$tag" "$head_sha" 2>/dev/null; then
        previous="$tag"
        break
    fi
done < <(git tag --list 'v*' --sort=-version:refname)

if [[ -z "$previous" ]]; then
    printf '%s\n' "Initial Official Release"
    exit 0
fi

previous_sha="$(git rev-parse "${previous}^{commit}")"
if [[ "$previous_sha" == "$head_sha" ]]; then
    printf '%s\n' "No source changes since ${previous}"
    exit 0
fi

git log "${previous}..${head_sha}" --reverse --topo-order --format='%s' --no-merges \
    | awk 'NF { printf "- %s\n", $0 }'
