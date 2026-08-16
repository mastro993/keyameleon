#!/usr/bin/env bash
# Wait until GitHub check "Required CI gate" succeeds on a commit.
# Usage: wait-for-ci.sh <sha> [timeout-seconds]
set -euo pipefail

sha="${1:-}"
if [[ -z "$sha" ]]; then
    echo "usage: wait-for-ci.sh <sha> [timeout-seconds]" >&2
    exit 64
fi

timeout_s="${2:-2700}"
poll_s=20
check_name="Required CI gate"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
deadline=$((SECONDS + timeout_s))

latest_check() {
    # gh api --jq does not accept jq --arg (becomes extra endpoint args).
    gh api "repos/${repo}/commits/${sha}/check-runs" \
        | jq --arg name "$check_name" '
          [.check_runs[] | select(.name == $name)]
          | sort_by(.started_at // .completed_at // "")
          | last
        '
}

while (( SECONDS < deadline )); do
    check="$(latest_check)"
    if [[ -z "$check" || "$check" == "null" ]]; then
        echo "no ${check_name} check yet for ${sha}; waiting"
        sleep "$poll_s"
        continue
    fi

    status="$(jq -r '.status' <<<"$check")"
    conclusion="$(jq -r '.conclusion // empty' <<<"$check")"
    echo "${check_name}: status=${status} conclusion=${conclusion:-<none>}"

    if [[ "$status" != "completed" ]]; then
        sleep "$poll_s"
        continue
    fi

    if [[ "$conclusion" == "success" ]]; then
        echo "CI succeeded for ${sha}"
        exit 0
    fi

    echo "CI ${conclusion} for ${sha}" >&2
    exit 1
done

echo "timed out after ${timeout_s}s waiting for ${check_name} on ${sha}" >&2
exit 1
