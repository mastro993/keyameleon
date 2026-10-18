#!/usr/bin/env bash
# Require DEFAULT_BRANCH to hold the validated release version commit.
# Env: DEFAULT_BRANCH, SOURCE_SHA, VERSION. Writes commit= to GITHUB_OUTPUT.
set -euo pipefail
git fetch origin "${DEFAULT_BRANCH}"
remote_sha="$(git rev-parse "origin/${DEFAULT_BRANCH}")"
test "$(git log -1 --format=%P "${remote_sha}")" = "${SOURCE_SHA}"
test "$(git log -1 --format=%s "${remote_sha}")" = "chore(release): ${VERSION}"
expected_files="$(printf '%s\n' Keyameleon.xcodeproj/project.pbxproj project.yml | sort)"
test "$(git diff-tree --no-commit-id --name-only -r "${remote_sha}" | sort)" = "${expected_files}"
git show "${remote_sha}:project.yml" | grep -Fxq "    MARKETING_VERSION: \"${VERSION}\""
echo "commit=${remote_sha}" >> "$GITHUB_OUTPUT"
