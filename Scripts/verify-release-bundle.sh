#!/usr/bin/env bash
# Require a complete artifact bundle in dist/ bound to the release commit and tag.
# Env: VERSION, TAG, COMMIT.
set -euo pipefail
test -s "dist/Keyameleon-${VERSION}.dmg"
test -s dist/appcast.xml
test -s dist/release-evidence.json
test "$(python3 -c 'import json; print(json.load(open("dist/release-evidence.json"))["gitCommit"])')" = "$COMMIT"
test "$(python3 -c 'import json; print(json.load(open("dist/release-evidence.json"))["tag"])')" = "$TAG"
python3 Scripts/verify-release-appcast.py \
  --appcast dist/appcast.xml --evidence dist/release-evidence.json \
  --artifact "dist/Keyameleon-${VERSION}.dmg"
