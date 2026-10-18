#!/usr/bin/env bash
# Restore this run's saved release artifacts into dist/, or prove none exist yet.
# Env: GH_TOKEN, VERSION, TAG, GITHUB_REPOSITORY, GITHUB_RUN_ID.
# Writes restored= to GITHUB_OUTPUT.
set -euo pipefail
artifact_name="official-release-${VERSION}"
artifact_id="$(gh api --paginate --slurp \
  "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts" \
  | jq -r --arg name "${artifact_name}" '[.[].artifacts[] | select(.name == $name)] |
    if length == 0 then ""
    elif length != 1 or .[0].expired then error("saved release artifact is ambiguous or expired")
    else .[0].id end')"
if [[ -n "${artifact_id}" ]]; then
  gh run download "${GITHUB_RUN_ID}" --name "${artifact_name}" --dir dist
  echo "restored=true" >> "$GITHUB_OUTPUT"
else
  remote_tag="$(git ls-remote --tags origin "refs/tags/${TAG}")"
  test -z "${remote_tag}"
  release_id="$(gh api --paginate "repos/${GITHUB_REPOSITORY}/releases" \
    --jq '.[] | select(.tag_name == "'"${TAG}"'") | .id')"
  test -z "${release_id}"
  echo "restored=false" >> "$GITHUB_OUTPUT"
fi
