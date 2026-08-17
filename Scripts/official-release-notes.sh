#!/usr/bin/env bash
# Prints the Official Release page body.
#
# The new tag does not need to exist yet. Pass it with --tag so the script can
# build the comparison URL while still finding the previous Official Release.
# Commit subjects are grouped into visible change sections. The Changelog keeps
# short commit links and adds pull-request links and @login authors when GitHub
# provides them. Contributors are GitHub avatar images, not bare names.
set -euo pipefail

usage() {
    echo "usage: official-release-notes.sh --tag vX.Y.Z [--head <rev>]" >&2
    exit 64
}

release_tag="${RELEASE_TAG:-}"
head_rev="HEAD"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            release_tag="${2:-}"
            shift 2
            ;;
        --head)
            head_rev="${2:-}"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$release_tag" ]]; then
    release_tag="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
fi
if [[ -z "$release_tag" ]]; then
    echo "an Official Release tag is required; pass --tag vX.Y.Z" >&2
    exit 64
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
version="$("${script_dir}/verify-official-release-tag.sh" "$release_tag")"
head_sha="$(git rev-parse "${head_rev}^{commit}")"

repo_slug="${GITHUB_REPOSITORY:-}"
if [[ -z "$repo_slug" ]]; then
    remote_url="$(git config --get remote.origin.url || true)"
    remote_url="${remote_url%.git}"
    case "$remote_url" in
        https://github.com/*)
            repo_slug="${remote_url#https://github.com/}"
            ;;
        git@github.com:*)
            repo_slug="${remote_url#git@github.com:}"
            ;;
    esac
fi
if [[ -z "$repo_slug" ]]; then
    echo "cannot determine GitHub repository; set GITHUB_REPOSITORY" >&2
    exit 1
fi

previous=""
while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    [[ "$candidate" == "$release_tag" ]] && continue
    if ! "${script_dir}/verify-official-release-tag.sh" "$candidate" >/dev/null 2>&1; then
        continue
    fi
    if git merge-base --is-ancestor "$candidate" "$head_sha" 2>/dev/null; then
        previous="$candidate"
        break
    fi
done < <(git tag --list 'v*' --sort=-version:refname)

commit_file="$(mktemp "${TMPDIR:-/tmp}/keyameleon-release-notes.XXXXXX")"
cleanup() {
    rm -f "$commit_file"
}
trap cleanup EXIT

if [[ -n "$previous" ]]; then
    git log "${previous}..${head_sha}" --reverse --topo-order --no-merges \
        --format='%H%x09%an%x09%s' >"$commit_file"
else
    git log "$head_sha" --reverse --topo-order --no-merges \
        --format='%H%x09%an%x09%s' >"$commit_file"
fi

category_for_subject() {
    local subject="$1"
    local lower="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        feat:*|feat\(*|feat\ *|feature:*|feature\(*|feature\ *|add:*|add\ *|added:*|new:*|new\ *)
            printf '%s\n' "New Features"
            ;;
        refactor:*|refactor\(*|refactor\ *|enhance:*|enhance\ *|improve:*|improve\ *)
            printf '%s\n' "Refactor"
            ;;
        chore:*|chore\(*|style:*|style\(*|docs:*|docs\(*|perf:*|perf\(*|test:*|test\(*|ci:*|ci\(*|build:*|build\(*)
            printf '%s\n' "Chores"
            ;;
        *)
            printf '%s\n' "Bug Fixes"
            ;;
    esac
}

declare -a new_features=()
declare -a bug_fixes=()
declare -a refactors=()
declare -a chores=()
declare -a changelog=()
declare -a contributors=()
declare -a contributor_keys=()

github_available() {
    [[ -n "$repo_slug" && -n "${GH_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1
}

# number<TAB>login<TAB>id
lookup_pull_request() {
    local sha="$1"
    local result=""
    if github_available; then
        result="$(gh api "repos/${repo_slug}/commits/${sha}/pulls" \
            -H 'Accept: application/vnd.github+json' \
            --jq 'if length > 0 then (.[] | "\(.number)\t\(.user.login // \"\")\t\(.user.id // \"\")") else empty end' \
            2>/dev/null | head -n 1 || true)"
    fi
    printf '%s\n' "$result"
}

# login<TAB>id — commit author GitHub user, when the email is linked
lookup_commit_author() {
    local sha="$1"
    local result=""
    if github_available; then
        result="$(gh api "repos/${repo_slug}/commits/${sha}" \
            --jq 'if .author != null and .author.login != null then "\(.author.login)\t\(.author.id // \"\")" else empty end' \
            2>/dev/null || true)"
    fi
    printf '%s\n' "$result"
}

# Avatar image linking to the GitHub profile.
contributor_line() {
    local login="$1"
    local user_id="$2"
    local name="$3"
    local avatar_login="${login%\[bot\]}"
    if [[ -n "$login" && -n "$user_id" ]]; then
        printf -- '- [![@%s](https://avatars.githubusercontent.com/u/%s?s=64&v=4)](https://github.com/%s)' \
            "$avatar_login" "$user_id" "$avatar_login"
    elif [[ -n "$login" ]]; then
        printf -- '- [![@%s](https://github.com/%s.png?size=64)](https://github.com/%s)' \
            "$avatar_login" "$avatar_login" "$avatar_login"
    elif [[ -n "$name" ]]; then
        printf -- '- %s' "$name"
    fi
}

while IFS=$'\t' read -r sha author subject; do
    [[ -n "$sha" ]] || continue

    short_sha="${sha:0:7}"
    pull_number=""
    github_login=""
    github_id=""
    if [[ "$subject" =~ \(#([0-9]+)\)$ ]]; then
        pull_number="${BASH_REMATCH[1]}"
    fi
    pull_data="$(lookup_pull_request "$sha")"
    if [[ -n "$pull_data" ]]; then
        api_pull_number=""
        api_pull_login=""
        api_pull_id=""
        IFS=$'\t' read -r api_pull_number api_pull_login api_pull_id <<<"$pull_data"
        [[ -n "$pull_number" ]] || pull_number="$api_pull_number"
        github_login="$api_pull_login"
        github_id="$api_pull_id"
    fi
    if [[ -z "$github_login" ]]; then
        author_data="$(lookup_commit_author "$sha")"
        if [[ -n "$author_data" ]]; then
            IFS=$'\t' read -r github_login github_id <<<"$author_data"
        fi
    fi

    display_subject="$(printf '%s' "$subject" | sed -E 's/ \(#[0-9]+\)$//')"
    change_line="- ${display_subject}"
    if [[ -n "$pull_number" ]]; then
        change_line+=" ([#${pull_number}](https://github.com/${repo_slug}/pull/${pull_number}))"
    fi
    if [[ -n "$github_login" ]]; then
        change_line+=" by @${github_login}"
    elif [[ -n "$author" ]]; then
        change_line+=" by ${author}"
    fi

    category="$(category_for_subject "$subject")"
    case "$category" in
        "New Features") new_features+=("$change_line") ;;
        "Bug Fixes") bug_fixes+=("$change_line") ;;
        Refactor) refactors+=("$change_line") ;;
        Chores) chores+=("$change_line") ;;
    esac

    commit_link="- [${short_sha}](https://github.com/${repo_slug}/commit/${sha}) $subject"
    if [[ -n "$github_login" ]]; then
        commit_link+=" by @${github_login}"
    elif [[ -n "$author" ]]; then
        commit_link+=" by ${author}"
    fi
    changelog+=("$commit_link")

    contributor="${github_login:-$author}"
    contributor_seen=0
    for existing_contributor in "${contributor_keys[@]-}"; do
        if [[ "$existing_contributor" == "$contributor" ]]; then
            contributor_seen=1
            break
        fi
    done
    if [[ -n "$contributor" && "$contributor_seen" -eq 0 ]]; then
        contributor_keys+=("$contributor")
        contributors+=("$(contributor_line "$github_login" "$github_id" "$author")")
    fi
done <"$commit_file"

emit_category() {
    local title="$1"
    shift
    local entries=("$@")
    if [[ "${#entries[@]}" -eq 0 || ( "${#entries[@]}" -eq 1 && -z "${entries[0]}" ) ]]; then
        return
    fi
    printf '### %s\n\n' "$title"
    printf '%s\n' "${entries[@]}"
    printf '\n'
}

printf '## v%s\n\n' "$version"
emit_category "New Features" "${new_features[@]-}"
emit_category "Bug Fixes" "${bug_fixes[@]-}"
emit_category "Refactor" "${refactors[@]-}"
emit_category "Chores" "${chores[@]-}"
printf '%s\n' '---'
printf '\n### Changelog\n\n'
if [[ -n "$previous" && -n "$repo_slug" ]]; then
    printf '**Full Changelog**: [%s...%s](https://github.com/%s/compare/%s...%s)\n\n' \
        "$previous" "$release_tag" "$repo_slug" "$previous" "$release_tag"
elif [[ -n "$repo_slug" ]]; then
    printf '**Full Changelog**: [Initial history](https://github.com/%s/commits/%s)\n\n' \
        "$repo_slug" "$release_tag"
else
    printf '**Full Changelog**: %s\n\n' "Initial history"
fi

if [[ "${#changelog[@]}" -eq 0 ]]; then
    if [[ -n "$previous" ]]; then
        printf '%s\n' "- No source changes since ${previous}"
    else
        printf '%s\n' '- Initial Official Release'
    fi
else
    printf '%s\n' "${changelog[@]}"
fi

printf '\n### Contributors\n\n'
if [[ "${#contributors[@]}" -eq 0 ]]; then
    printf '%s\n' '- None listed.'
else
    printf '%s\n' "${contributors[@]}"
fi
