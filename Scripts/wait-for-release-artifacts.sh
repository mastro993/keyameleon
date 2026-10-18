#!/usr/bin/env bash
# Wait for this run's saved release artifacts and download them into dist/.
# Env: GH_TOKEN, VERSION, GITHUB_REPOSITORY, GITHUB_RUN_ID.
set -euo pipefail
artifact_name="official-release-${VERSION}"
for attempt in {1..180}; do
  artifact_id="$(gh api --paginate --slurp \
    "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts" \
    | jq -r --arg name "${artifact_name}" '[.[].artifacts[] | select(.name == $name)] |
      if length == 0 then ""
      elif length != 1 or .[0].expired then error("saved release artifact is ambiguous or expired")
      else .[0].id end')"
  if [[ -n "${artifact_id}" ]]; then
    gh run download "${GITHUB_RUN_ID}" --name "${artifact_name}" --dir dist
    exit 0
  fi
  echo "attempt ${attempt}: waiting for the saved release artifact" >&2
  sleep 30
done
echo "timed out waiting for the saved release artifact" >&2
exit 1
