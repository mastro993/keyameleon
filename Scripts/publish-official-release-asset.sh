#!/usr/bin/env bash
# Publish or reuse the exact DMG before the appcast can be exposed.
set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "usage: $0 TAG VERSION NOTES_FILE DIST_DIR DOWNLOAD_DIR" >&2
    exit 64
fi

tag="$1"
version="$2"
notes_file="$3"
dist_dir="$4"
download_dir="$5"
archive="Keyameleon-${version}.dmg"
artifact="${dist_dir}/${archive}"
evidence="${dist_dir}/release-evidence.json"
appcast="${dist_dir}/appcast.xml"
script_dir="$(cd "$(dirname "$0")" && pwd)"

python3 "${script_dir}/verify-release-appcast.py" \
    --appcast "$appcast" --evidence "$evidence" --artifact "$artifact"

if ! gh release view "$tag" --json isDraft >/dev/null 2>&1; then
    gh release create "$tag" "$artifact" \
        --title "Keyameleon ${version}" \
        --notes-file "$notes_file" \
        --verify-tag
fi

assets="$(gh release view "$tag" --json assets)"
asset_state="$(jq -r --arg name "$archive" '.assets[] | select(.name == $name) | .state' <<< "$assets")"
case "$asset_state" in
    uploaded)
        ;;
    starter)
        # GitHub can leave an empty asset after a failed upload. Delete only
        # that asset by ID; never replace an uploaded DMG.
        asset_url="$(jq -r --arg name "$archive" '.assets[] | select(.name == $name) | .apiUrl' <<< "$assets")"
        asset_id="${asset_url##*/}"
        if [[ ! "$asset_id" =~ ^[0-9]+$ ]]; then
            echo "invalid starter asset ID: ${asset_id}" >&2
            exit 1
        fi
        gh api --method DELETE "repos/mastro993/keyameleon/releases/assets/${asset_id}"
        gh release upload "$tag" "$artifact"
        ;;
    "")
        # A previous create may have stopped after creating a draft.
        gh release upload "$tag" "$artifact"
        ;;
    *)
        echo "unexpected state for ${archive}: ${asset_state}" >&2
        exit 1
        ;;
esac

if [[ "$(gh release view "$tag" --json isDraft --jq '.isDraft')" == true ]]; then
    gh release edit "$tag" --draft=false
fi

mkdir -p "$download_dir"
public_url="https://github.com/mastro993/Keyameleon/releases/download/${tag}/${archive}"
downloaded="${download_dir}/${archive}"
curl -fLsS --retry 10 --retry-all-errors --retry-delay 6 \
    --output "$downloaded" "$public_url"
python3 "${script_dir}/verify-release-appcast.py" \
    --appcast "$appcast" --evidence "$evidence" --artifact "$downloaded"
