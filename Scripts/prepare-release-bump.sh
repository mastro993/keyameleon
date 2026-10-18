#!/usr/bin/env bash
# Create the release version commit on top of SOURCE_SHA, or reuse the one a
# previous attempt already pushed to DEFAULT_BRANCH.
# Env: GH_TOKEN, TAG, DEFAULT_BRANCH, RELEASE_TYPE, SOURCE_SHA, VERSION,
# GITHUB_REPOSITORY, GITHUB_RUN_ID. Writes commit= and reused= to GITHUB_OUTPUT.
set -euo pipefail
expected_files="$(printf '%s\n' Keyameleon.xcodeproj/project.pbxproj project.yml | sort)"
expected_subject="chore(release): ${VERSION}"
git fetch origin "${DEFAULT_BRANCH}"
remote_sha="$(git rev-parse "origin/${DEFAULT_BRANCH}")"

if [[ "${remote_sha}" != "${SOURCE_SHA}" ]]; then
  remote_parent="$(git log -1 --format=%P "${remote_sha}")"
  remote_subject="$(git log -1 --format=%s "${remote_sha}")"
  remote_files="$(git diff-tree --no-commit-id --name-only -r "${remote_sha}" | sort)"
  if [[ "${remote_parent}" == "${SOURCE_SHA}" && \
        "${remote_subject}" == "${expected_subject}" && \
        "${remote_files}" == "${expected_files}" ]]; then
    git checkout --detach "${remote_sha}"
    grep -Fxq "    MARKETING_VERSION: \"${VERSION}\"" project.yml
    echo "commit=${remote_sha}" >> "$GITHUB_OUTPUT"
    echo "reused=true" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "main changed before the release bump; dispatch again from current main" >&2
  exit 1
fi

artifact_count="$(gh api --paginate --slurp \
  "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts" \
  | jq --arg name "official-release-${VERSION}" '[.[].artifacts[] | select(.name == $name)] | length')"
test "${artifact_count}" = 0
remote_tag="$(git ls-remote --tags origin "refs/tags/${TAG}")"
test -z "${remote_tag}"
release_id="$(gh api --paginate "repos/${GITHUB_REPOSITORY}/releases" \
  --jq '.[] | select(.tag_name == "'"${TAG}"'") | .id')"
test -z "${release_id}"

calculated="$(python3 Scripts/release-version.py "${RELEASE_TYPE}" --write)"
if [[ "${calculated}" != "${VERSION}" ]]; then
  echo "release version changed: expected ${VERSION}, got ${calculated}" >&2
  exit 1
fi

xcodegen generate --spec project.yml
git diff --check
changed_files="$(git diff --name-only | sort)"
if [[ "${changed_files}" != "${expected_files}" ]]; then
  echo "unexpected release-bump files:" >&2
  printf '%s\n' "${changed_files}" >&2
  exit 1
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add project.yml Keyameleon.xcodeproj/project.pbxproj
git commit -m "chore(release): ${VERSION}"
echo "commit=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
echo "reused=false" >> "$GITHUB_OUTPUT"
