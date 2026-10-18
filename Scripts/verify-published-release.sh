#!/usr/bin/env bash
# Wait until the published feed and evidence match dist/ byte for byte and the
# feed resolves to the verified public DMG.
# Env: VERSION, RUNNER_TEMP.
set -euo pipefail
feed_url="$(python3 -c 'import json; print(json.load(open("dist/release-evidence.json"))["feedURLString"])')"
archive="Keyameleon-${VERSION}.dmg"
tag="v${VERSION}"
evidence_url="https://mastro993.github.io/keyameleon/releases/${tag}/release-evidence.json"
for attempt in {1..20}; do
  if curl -fsSL -o "$RUNNER_TEMP/published-appcast.xml" "$feed_url" 2>/dev/null && \
    cmp -s "$RUNNER_TEMP/published-appcast.xml" dist/appcast.xml && \
    curl -fsSL -o "$RUNNER_TEMP/published-evidence.json" "$evidence_url" 2>/dev/null && \
    cmp -s "$RUNNER_TEMP/published-evidence.json" dist/release-evidence.json && \
    python3 Scripts/verify-release-appcast.py \
      --appcast "$RUNNER_TEMP/published-appcast.xml" \
      --expected-appcast dist/appcast.xml \
      --evidence "$RUNNER_TEMP/published-evidence.json" \
      --artifact "$RUNNER_TEMP/release-asset/${archive}"; then
    echo "feed ${feed_url} and evidence ${evidence_url} serve verified ${VERSION} enclosure"
    exit 0
  fi
  echo "attempt ${attempt}: ${feed_url} does not serve verified ${VERSION} enclosure yet" >&2
  sleep 6
done
echo "feed ${feed_url} does not serve verified ${VERSION} enclosure" >&2
exit 1
