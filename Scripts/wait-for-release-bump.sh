#!/usr/bin/env bash
# Wait until DEFAULT_BRANCH holds the validated release version commit.
# Env: DEFAULT_BRANCH, SOURCE_SHA, VERSION. Writes commit= to GITHUB_OUTPUT.
set -euo pipefail
expected_files="$(printf '%s\n' Keyameleon.xcodeproj/project.pbxproj project.yml | sort)"
for attempt in {1..180}; do
  git fetch origin "${DEFAULT_BRANCH}"
  remote_sha="$(git rev-parse "origin/${DEFAULT_BRANCH}")"
  if [[ "${remote_sha}" != "${SOURCE_SHA}" ]]; then
    test "$(git log -1 --format=%P "${remote_sha}")" = "${SOURCE_SHA}"
    test "$(git log -1 --format=%s "${remote_sha}")" = "chore(release): ${VERSION}"
    test "$(git diff-tree --no-commit-id --name-only -r "${remote_sha}" | sort)" = "${expected_files}"
    git show "${remote_sha}:project.yml" | grep -Fxq "    MARKETING_VERSION: \"${VERSION}\""
    echo "commit=${remote_sha}" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "attempt ${attempt}: waiting for the release bump on main" >&2
  sleep 10
done
echo "timed out waiting for the release bump on main" >&2
exit 1
