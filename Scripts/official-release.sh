#!/bin/zsh
# Produce Official Release artifacts: Developer ID signed, hardened runtime,
# timestamped, notarized, stapled archive + Sparkle appcast + release evidence.
#
# Required environment (never commit these values):
#   APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64
#   APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
#   APPLE_API_KEY_ID
#   APPLE_API_ISSUER_ID
#   APPLE_API_KEY_P8_BASE64   # contents of AuthKey_XXX.p8, base64
#   APPLE_TEAM_ID
#   SPARKLE_PRIVATE_ED_KEY    # generate_keys -x output (32-byte seed, base64)
#   SPARKLE_PUBLIC_ED_KEY     # generate_keys -p output (base64 SUPublicEDKey)
#
# Optional:
#   RELEASE_TAG               # default: current git tag at HEAD
#   CODESIGN_IDENTITY         # default: Developer ID Application
#   SKIP_NOTARIZE=1           # build+sign+zip only (local dry path)
set -euo pipefail

cd "${0:A:h}/.."

script_dir="${0:A:h}"
derived_data="${PWD}/build/official-release"
dist_dir="${PWD}/dist"
keychain_name="keyameleon-official-release.keychain-db"
keychain_password="$(openssl rand -base64 32)"
work_tmpdir=""
imported_cert=0

cleanup() {
    set +e
    if [[ "$imported_cert" -eq 1 ]]; then
        security delete-keychain "$keychain_name" 2>/dev/null
    fi
    if [[ -n "$work_tmpdir" && -d "$work_tmpdir" ]]; then
        rm -rf "$work_tmpdir"
    fi
}
trap cleanup EXIT

require_env() {
    local name="$1"
    if [[ -z "${(P)name:-}" ]]; then
        print -u2 "missing required environment variable: ${name}"
        exit 1
    fi
}

require_env APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64
require_env APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
require_env SPARKLE_PUBLIC_ED_KEY
require_env SPARKLE_PRIVATE_ED_KEY

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    require_env APPLE_API_KEY_ID
    require_env APPLE_API_ISSUER_ID
    require_env APPLE_API_KEY_P8_BASE64
    require_env APPLE_TEAM_ID
fi

if [[ -n "${RELEASE_TAG:-}" ]]; then
    tag="$RELEASE_TAG"
else
    tag="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
fi
if [[ -z "$tag" ]]; then
    print -u2 "HEAD is not an Official Release tag; set RELEASE_TAG=vX.Y.Z"
    exit 1
fi

version="$("${script_dir}/verify-official-release-tag.sh" "$tag")"
git_commit="$(git rev-parse HEAD)"
codesign_identity="${CODESIGN_IDENTITY:-Developer ID Application}"

print "Official Release ${tag} (${version}) @ ${git_commit}"

work_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/keyameleon-release.XXXXXX")"

# Normalize Sparkle keys before archive/notary.
# GH secret paste often wraps the seed (quotes, PEM, trailing newline).
# generate_appcast --ed-key-file - then dies: "isn't base64 encoded".
sparkle_private_key_path="${work_tmpdir}/sparkle_eddsa_private.key"
sparkle_public_key_path="${work_tmpdir}/sparkle_eddsa_public.key"
printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | python3 "${script_dir}/normalize-sparkle-ed-key.py" \
    "$sparkle_private_key_path"
printf '%s' "$SPARKLE_PUBLIC_ED_KEY" | python3 "${script_dir}/normalize-sparkle-ed-key.py" \
    "$sparkle_public_key_path"
chmod 600 "$sparkle_private_key_path"
SPARKLE_PUBLIC_ED_KEY="$(cat "$sparkle_public_key_path")"

cert_path="${work_tmpdir}/developer-id.p12"
print -n "$APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64" | base64 --decode >"$cert_path"

security create-keychain -p "$keychain_password" "$keychain_name"
security set-keychain-settings -lut 21600 "$keychain_name"
security unlock-keychain -p "$keychain_password" "$keychain_name"
security import "$cert_path" \
    -k "$keychain_name" \
    -P "$APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_name"
security list-keychains -d user -s "$keychain_name" $(security list-keychains -d user | sed -e 's/"//g')
imported_cert=1

# Resolve Sparkle tools from SwiftPM checkouts after project generation.
xcodegen generate --spec project.yml

# Embed Sparkle public key and version for this Official Release only.
info_plist_src="Sources/App/Info.plist"
info_plist_backup="${work_tmpdir}/Info.plist.bak"
cp "$info_plist_src" "$info_plist_backup"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "$info_plist_src"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version}" "$info_plist_src" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${version}" "$info_plist_src"
if /usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$info_plist_src" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${SPARKLE_PUBLIC_ED_KEY}" "$info_plist_src"
else
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_ED_KEY}" "$info_plist_src"
fi

restore_info_plist() {
    if [[ -f "$info_plist_backup" ]]; then
        cp "$info_plist_backup" "$info_plist_src"
    fi
}
trap 'restore_info_plist; cleanup' EXIT

xcodebuild archive \
    -project Keyameleon.xcodeproj \
    -scheme Keyameleon \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "${derived_data}/Keyameleon.xcarchive" \
    -derivedDataPath "${derived_data}/DerivedData" \
    MARKETING_VERSION="${version}" \
    CURRENT_PROJECT_VERSION="${version}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${codesign_identity}" \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"

app_path="${derived_data}/Keyameleon.xcarchive/Products/Applications/Keyameleon.app"
if [[ ! -d "$app_path" ]]; then
    print -u2 "archived app missing at ${app_path}"
    exit 1
fi

# Re-sign with hardened runtime + secure timestamp explicitly.
codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$codesign_identity" \
    "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"
# Gatekeeper assess is only valid after notarization + staple.

mkdir -p "$dist_dir" "${work_tmpdir}/updates"
archive_path="${dist_dir}/Keyameleon-${version}.zip"
rm -f "$archive_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    api_key_path="${work_tmpdir}/AuthKey_${APPLE_API_KEY_ID}.p8"
    print -n "$APPLE_API_KEY_P8_BASE64" | base64 --decode >"$api_key_path"

    xcrun notarytool submit "$archive_path" \
        --key "$api_key_path" \
        --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER_ID" \
        --wait

    # Staple the app, then re-zip so the stapled ticket ships in the archive.
    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
    spctl --assess --type execute --verbose=4 "$app_path"
    rm -f "$archive_path"
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
fi

# Sparkle tools live in the resolved package checkout after the archive build.
sparkle_checkouts=(
    "${derived_data}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
    "${derived_data}/DerivedData/SourcePackages/checkouts/Sparkle/bin"
)
generate_appcast=""
for candidate in "${sparkle_checkouts[@]}"; do
    if [[ -x "${candidate}/generate_appcast" ]]; then
        generate_appcast="${candidate}/generate_appcast"
        break
    fi
done
if [[ -z "$generate_appcast" ]]; then
    # Fallback: download Sparkle distribution matching Package.resolved pin when tools absent.
    sparkle_version="$(python3 - <<'PY'
import json
from pathlib import Path
resolved = Path("Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
data = json.loads(resolved.read_text())
for pin in data.get("pins", []):
    if pin.get("identity") == "sparkle":
        print(pin["state"]["version"])
        break
else:
    raise SystemExit("sparkle pin missing")
PY
)"
    sparkle_url="https://github.com/sparkle-project/Sparkle/releases/download/${sparkle_version}/Sparkle-${sparkle_version}.tar.xz"
    curl -fsSL "$sparkle_url" -o "${work_tmpdir}/Sparkle.tar.xz"
    mkdir -p "${work_tmpdir}/sparkle-dist"
    tar -xJf "${work_tmpdir}/Sparkle.tar.xz" -C "${work_tmpdir}/sparkle-dist"
    generate_appcast="$(find "${work_tmpdir}/sparkle-dist" -type f -name generate_appcast | head -n 1)"
fi
if [[ -z "$generate_appcast" || ! -x "$generate_appcast" ]]; then
    print -u2 "generate_appcast not found"
    exit 1
fi

cp "$archive_path" "${work_tmpdir}/updates/Keyameleon-${version}.zip"
# Key file lives in work_tmpdir only (cleaned on EXIT). Never write to the repo tree.
"${generate_appcast}" \
    --ed-key-file "$sparkle_private_key_path" \
    -o "${dist_dir}/appcast.xml" \
    "${work_tmpdir}/updates"

# Point enclosure URLs at GitHub Releases for the Stable Channel.
python3 - "$version" "${dist_dir}/appcast.xml" <<'PY'
import re
import sys
from pathlib import Path

version, path = sys.argv[1], Path(sys.argv[2])
text = path.read_text(encoding="utf-8")
base = "https://github.com/mastro993/Keyameleon/releases/download"
# generate_appcast may emit file URLs; rewrite to the tag download URL.
pattern = re.compile(
    r'url="[^"]*Keyameleon-' + re.escape(version) + r'\.zip"'
)
replacement = f'url="{base}/v{version}/Keyameleon-{version}.zip"'
text, count = pattern.subn(replacement, text)
if count == 0:
    # Also rewrite generic enclosure urls ending with the archive name.
    pattern = re.compile(r'(<enclosure[^>]*url=")[^"]+(")')
    def repl(match: re.Match[str]) -> str:
        return match.group(1) + f"{base}/v{version}/Keyameleon-{version}.zip" + match.group(2)
    text, count = pattern.subn(repl, text)
if count == 0:
    raise SystemExit("failed to rewrite appcast enclosure URL")
path.write_text(text, encoding="utf-8")
print(f"rewrote {count} enclosure URL(s)")
PY

evidence_path="${dist_dir}/release-evidence.json"
"${script_dir}/write-release-evidence.sh" \
    --tag "$tag" \
    --commit "$git_commit" \
    --artifact "$archive_path" \
    --output "$evidence_path"

# Source archive for the stable channel (reproducible tree at the tag commit).
source_archive="${dist_dir}/Keyameleon-source-${version}.tar.gz"
git archive --format=tar.gz --prefix="Keyameleon-${version}/" -o "$source_archive" "$git_commit"

print "artifacts:"
print "  ${archive_path}"
print "  ${source_archive}"
print "  ${dist_dir}/appcast.xml"
print "  ${evidence_path}"
