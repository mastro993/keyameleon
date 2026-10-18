#!/usr/bin/env bash
# Write the release notes and create or verify the annotated Official Release tag.
# Env: GH_TOKEN, GITHUB_REPOSITORY, VERSION, TAG, COMMIT, SOURCE_SHA, RUNNER_TEMP.
# Writes $RUNNER_TEMP/release-notes.md.
set -euo pipefail
# The notes script excludes TAG if this job is resuming after the tag
# was created but before the GitHub Release was published.
CHANGES="$(./Scripts/official-release-notes.sh --tag "$TAG" --head "${SOURCE_SHA}")"
printf '%s\n' "$CHANGES" >"$RUNNER_TEMP/release-notes.md"
printf '\nPermanent release evidence: https://mastro993.github.io/keyameleon/releases/%s/release-evidence.json\n' "$TAG" >>"$RUNNER_TEMP/release-notes.md"

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null; then
  tagged_commit="$(git ls-remote --tags origin "refs/tags/${TAG}^{}" | awk '{print $1}')"
  if [[ "${tagged_commit}" != "$COMMIT" ]]; then
    echo "existing tag ${TAG} does not point to the release commit" >&2
    exit 1
  fi
else
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git tag -a "$TAG" "$COMMIT" -m "Keyameleon ${VERSION}"
  git push origin "$TAG"
fi
