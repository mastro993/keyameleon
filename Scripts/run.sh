#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "${script_dir}/.."

DERIVED_DATA_PATH="${PWD}/build"
PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug"
# `test` builds an ad hoc app. Its own derived data keeps it from replacing the
# signed app that `open` builds, whose Input Monitoring grant needs that signature.
TEST_DERIVED_DATA_PATH="${DERIVED_DATA_PATH}/test"
TEST_PRODUCTS_PATH="${TEST_DERIVED_DATA_PATH}/Build/Products/Debug"
# Debug builds have their own identity; the release one belongs to the installed
# app (docs/adr/0008-separate-debug-identity.md).
BUNDLE_ID='dev.fedemas.keyameleon.debug'
DEBUG_APP_NAME='Keyameleon (Dev)'
RELEASE_BUNDLE_ID='dev.fedemas.keyameleon'
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

audit_sources() {
    local forbidden_pattern='HIDVirtualDevice|IOHIDUserDevice|IOHIDEventSystem|IOHIDPostEvent|IOHIDEvent|seizeDevice[[:space:]]*\(|kIOHIDRequestTypePostEvent|CGEvent(Post|Create|Tap)?|CGRequest(Post|Preflight)EventAccess|CGS[A-Za-z]|sendEvent[[:space:]]*\(|NSEvent[[:space:]]*\.[[:space:]]*(keyEvent|mouseEvent)|URLSession|URLRequest|NSURLConnection|URLProtocol|uploadTask|dataTask|Analytics|Telemetry|Sentry|Crashlytics|MetricKit|PLCrashReporter|diagnosticUpload|crashReportUpload|print[[:space:]]*\(|NSLog[[:space:]]*\(|os_log[[:space:]]*\('
    if grep -REn "$forbidden_pattern" Sources Tests project.yml; then
        print -u2 "forbidden source surface found"
        return 1
    fi

    local log_pipeline_paths=(
        Sources/Features/Shared/Log.swift
        Sources/Features/Shared/LogFile.swift
        Sources/Features/Shared/LogWriter.swift
        Sources/Features/Shared/LogLevel.swift
        Sources/Features/Shared/LogCategory.swift
    )
    local log_call_paths=(
        Sources/App/ApplicationDelegate.swift
        Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching*.swift
        Sources/Features/Shared/SetupModel*.swift
        Sources/Features/Shared/GeneralSettingsModel.swift
    )
    local key_content_path='KeyContent|rawReport|interpretedText|modifierState'
    local audited_path
    for audited_path in "${log_pipeline_paths[@]}" "${log_call_paths[@]}"; do
        if [[ ! -f "$audited_path" ]]; then
            print -u2 "audited path is missing: $audited_path"
            return 1
        fi
    done

    if grep -REn "PhysicalKeyboardEvent|${key_content_path}" "${log_pipeline_paths[@]}"; then
        print -u2 "prohibited Key Content path found"
        return 1
    fi

    if grep -REn "$key_content_path" "${log_call_paths[@]}"; then
        print -u2 "prohibited Key Content path found at a log call site"
        return 1
    fi

    if grep -REn --exclude='*.py' --exclude-dir=__pycache__ 'CFArrayGetValueAtIndex' Sources Tests; then
        print -u2 "raw CFArray element access found; bridge the array so its elements stay owned"
        return 1
    fi
}

lint_sources() {
    swiftlint lint --strict --quiet --no-cache --config .swiftlint.yml
}

# Xcode treats BuildLocationStyle=UseTargetSettings as legacy locations.
# Swift packages refuse to resolve: "Could not resolve package dependencies:
# Packages are not supported when using legacy build locations".
write_modern_workspace_settings() {
    local shared="Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings"
    mkdir -p "${shared:h}"
    cat > "$shared" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildLocationStyle</key>
	<string>UseAppPreferences</string>
	<key>DerivedDataLocationStyle</key>
	<string>Default</string>
</dict>
</plist>
EOF
}

# User WorkspaceSettings override shared. Neutralize UseTargetSettings so
# Xcode GUI Run (Debug) can resolve Sparkle.
neutralize_legacy_user_build_locations() {
    local settings style
    while IFS= read -r settings; do
        [[ -n "$settings" ]] || continue
        style="$(/usr/libexec/PlistBuddy -c 'Print :BuildLocationStyle' "$settings" 2>/dev/null || true)"
        if [[ "$style" == "UseTargetSettings" ]]; then
            /usr/libexec/PlistBuddy -c 'Set :BuildLocationStyle UseAppPreferences' "$settings"
        fi
    done < <(find Keyameleon.xcodeproj -path '*/xcuserdata/*/WorkspaceSettings.xcsettings' -type f 2>/dev/null)
}

generate_project() {
    local identity
    identity="$(development_signing_identity 2>/dev/null || true)"
    : > Config/Development.local.xcconfig
    if [[ -n "${identity}" ]]; then
        print -r -- "KEYAMELEON_DEVELOPMENT_SIGNING_IDENTITY = ${identity}" > Config/Development.local.xcconfig
    fi
    xcodegen generate --spec project.yml
    write_modern_workspace_settings
    neutralize_legacy_user_build_locations
}

kill_leftover_derived_data_keyameleon() {
    local pid command products
    /bin/ps -axww -o pid=,command= | while read -r pid command; do
        for products in "${PRODUCTS_PATH}" "${TEST_PRODUCTS_PATH}"; do
            case "${command}" in
                "${products}/${DEBUG_APP_NAME}.app/Contents/MacOS/Keyameleon"|\
                "${products}/${DEBUG_APP_NAME}.app/Contents/MacOS/Keyameleon "*)
                    kill "${pid}" 2>/dev/null || true
                    ;;
            esac
        done
    done
}

run_tests() {
    local script test_status=0
    for script in Scripts/*.sh; do
        if [[ "$(head -n 1 "$script")" == *zsh ]]; then
            zsh -n "$script" || return $?
        else
            bash -n "$script" || return $?
        fi
    done
    python3 -m unittest discover -s Tests/Scripts -p 'test_*.py'
    kill_leftover_derived_data_keyameleon

    xcodebuild build-for-testing \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${TEST_DERIVED_DATA_PATH}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO

    xcodebuild test-without-building \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${TEST_DERIVED_DATA_PATH}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO || test_status=$?
    kill_leftover_derived_data_keyameleon
    # Quit & Reopen picks any registered copy with the bundle ID, so the ad hoc test
    # host must not stay registered beside the signed Debug app.
    "${LSREGISTER}" -u "${TEST_PRODUCTS_PATH}/${DEBUG_APP_NAME}.app" 2>/dev/null || true
    return "${test_status}"
}

build_app() {
    xcodebuild build \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -configuration Debug \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        "$@"
}

development_signing_identity() {
    local identity
    identity="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | awk '/Apple Development:/{ print $2; exit }'
    )"

    if [[ -z "${identity}" ]]; then
        print -u2 'No Apple Development signing identity found.'
        print -u2 'A stable signature is required for macOS to retain Input Monitoring permission.'
        return 1
    fi

    print -r -- "${identity}"
}

build_development_app() {
    local identity
    identity="$(development_signing_identity)"
    build_app \
        CODE_SIGN_STYLE=Manual \
        "CODE_SIGN_IDENTITY=${identity}" \
        CODE_SIGNING_REQUIRED=YES
}

# Prints one "PID<TAB>bundle path" line for each running Keyameleon of this user
# with one of the given bundle IDs; by default, Debug and release. Both hold the
# same single-instance lock (ADR 0002).
running_keyameleon_apps() {
    (( $# )) || set -- "${BUNDLE_ID}" "${RELEASE_BUNDLE_ID}"
    /usr/bin/osascript -l JavaScript \
        -e 'ObjC.import("AppKit")' \
        -e 'function run(ids) { return ids.flatMap(id => $.NSRunningApplication.runningApplicationsWithBundleIdentifier(id).js.map(app => app.processIdentifier + "\t" + app.bundleURL.path.js)).join("\n") }' \
        "$@"
}

# Takes the same bundle IDs as running_keyameleon_apps.
wait_until_no_keyameleon_runs() {
    local attempt running
    for (( attempt = 0; attempt < 50; attempt++ )); do
        running="$(running_keyameleon_apps "$@")" || return 1
        [[ -z "${running}" ]] && return 0
        sleep 0.2
    done
    print -u2 'A Keyameleon process is still running.'
    return 1
}

# Prints every bundle path LaunchServices has registered for BUNDLE_ID.
# macOS's Quit & Reopen (offered after an Input Monitoring change) relaunches by
# bundle ID, so with stale copies registered it can open a different Keyameleon.
registered_keyameleon_apps() {
    "${LSREGISTER}" -dump 2>/dev/null | awk -v id="${BUNDLE_ID}" '
        /^path:/ { sub(/^path:[[:space:]]+/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); path = $0 }
        /^identifier:/ && NF == 2 && $2 == id { print path }
    ' | sort -u
}

# Returns this Mac to a never-installed state for one identity, so its next launch
# is a first run: the Debug identity, or the installed release's with --release.
# The other identity's running copies, permissions, Launch at Login item,
# preferences, and data stay untouched.
# The Keychain integrity key stays: it lives in the data-protection keychain,
# which the security CLI cannot reach, and it only signs data this reset deletes.
reset_local_state() {
    local pid bundle app running
    local -a apps
    # The functions called below read BUNDLE_ID, so --release switches them too.
    local BUNDLE_ID="${BUNDLE_ID}" folder='Keyameleon Dev'
    case "$*" in
        '') ;;
        --release)
            BUNDLE_ID="${RELEASE_BUNDLE_ID}"
            folder='Keyameleon'
            ;;
        *)
            print -u2 'usage: run.sh reset [--release]'
            return 64
            ;;
    esac

    running="$(running_keyameleon_apps "${BUNDLE_ID}")" || return 1
    while IFS=$'\t' read -r pid bundle; do
        [[ -n "${pid}" ]] || continue
        print "Quitting Keyameleon PID ${pid} at ${bundle}"
        kill "${pid}" 2>/dev/null || true
    done <<< "${running}"
    wait_until_no_keyameleon_runs "${BUNDLE_ID}" || return 1

    # tccutil resolves the bundle ID through LaunchServices, so it runs while
    # copies are still registered. With none registered it fails with -10814.
    if ! tccutil reset All "${BUNDLE_ID}"; then
        print -u2 'Could not reset privacy permissions; no registered copy of Keyameleon was found.'
    fi
    # Launch at Login is a Background Task Management item that outlives the app.
    # Debug builds made before ADR 0008 are named Keyameleon too, so only items at
    # this identity's registered paths are removed.
    apps=(${(f)"$(registered_keyameleon_apps)"}) || {
        print -u2 'Could not list the registered copies of Keyameleon.'
        return 1
    }
    if (( ${#apps} )) && ! osascript \
        -e 'on run appPaths' \
        -e 'repeat with appPath in appPaths' \
        -e 'set appPathText to contents of appPath' \
        -e 'tell application "System Events" to delete (every login item whose path is appPathText)' \
        -e 'end repeat' \
        -e 'end run' \
        "${apps[@]}"; then
        print -u2 'Could not remove the Launch at Login item; turn it off in System Settings > General > Login Items.'
    fi
    defaults delete "${BUNDLE_ID}" 2>/dev/null || true
    rm -rf "${HOME}/Library/Application Support/${folder}" "${HOME}/Library/Logs/${folder}" \
        "${HOME}/Library/Caches/${BUNDLE_ID}" "${HOME}/Library/HTTPStorages/${BUNDLE_ID}"

    # Only the release imports the legacy store, so only its reset deletes it.
    if [[ "${BUNDLE_ID}" == "${RELEASE_BUNDLE_ID}" ]]; then
        delete_legacy_store || return 1
    fi

    # Last, because tccutil above needs a registered copy. The next launched copy
    # registers itself again and becomes the one Quit & Reopen finds. Records for
    # deleted copies are never launched.
    for app in "${apps[@]}"; do
        [[ -d "${app}" ]] || continue
        print "Unregistering ${app}"
        if ! "${LSREGISTER}" -u "${app}"; then
            print -u2 "Could not unregister ${app}; Quit & Reopen may still open it."
            return 1
        fi
    done
    print "${folder} local state reset."
}

# Before 0.4.6 the store lived at SwiftData's shared default path, and a release
# launch copies it into the Keyameleon folder again. Other apps may use that path,
# so delete it only when Keyameleon's keyboard table is there and every other
# table is Keyameleon's or Core Data's own. Launch imports the file only under the
# same query (PhysicalKeyboardStoreMigration.keyameleonStoreQuery), so any other
# file is left untouched.
delete_legacy_store() {
    local legacy_store="${HOME}/Library/Application Support/default.store"
    local legacy_store_query="
        SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ZPHYSICALKEYBOARDRECORDMODEL')
            AND NOT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name NOT GLOB 'sqlite_*'
                AND name NOT IN (
                    'ZPHYSICALKEYBOARDRECORDMODEL', 'ZMANUALPHYSICALKEYBOARDDESIGNATIONMODEL',
                    'Z_PRIMARYKEY', 'Z_METADATA', 'Z_MODELCACHE',
                    'ACHANGE', 'ATRANSACTION', 'ATRANSACTIONSTRING'))"
    local is_keyameleon_store=''
    if [[ -f "${legacy_store}" ]] \
        && ! is_keyameleon_store="$(sqlite3 -readonly "${legacy_store}" "${legacy_store_query}")"; then
        print -u2 "Could not inspect ${legacy_store}, so it was kept. The next launch may copy its keyboards back."
        return 1
    fi
    if [[ "${is_keyameleon_store}" == 1 ]]; then
        print "Deleting legacy store ${legacy_store}"
        rm -f -- "${legacy_store}" "${legacy_store}-shm" "${legacy_store}-wal"
    fi
}

# Replaces only this checkout's Debug app. Any other running Keyameleon, Debug or an
# installed release, holds the single-instance lock and is never stopped here.
open_development_app() {
    local app="${PRODUCTS_PATH}/${DEBUG_APP_NAME}.app"
    local executable="${app}/Contents/MacOS/Keyameleon"
    local pid bundle attempt running
    local -a pids

    running="$(running_keyameleon_apps)" || return 1
    while IFS=$'\t' read -r pid bundle; do
        [[ -n "${pid}" ]] || continue
        if [[ "${bundle}" != "${app}" ]]; then
            print -u2 "Keyameleon is already running from ${bundle}. Quit it, then try again."
            return 1
        fi
        pids+=("${pid}")
    done <<< "${running}"

    for pid in "${pids[@]}"; do
        if ! kill "${pid}" 2>/dev/null && [[ -n "$(/bin/ps -p "${pid}" -o pid=)" ]]; then
            print -u2 "Could not stop the Debug app PID ${pid}."
            return 1
        fi
    done

    wait_until_no_keyameleon_runs || return 1

    open -n -a "${app}"
    for (( attempt = 0; attempt < 50; attempt++ )); do
        if /bin/ps -axww -o comm= | grep -Fx "${executable}" > /dev/null; then
            sleep 1
            /bin/ps -axww -o comm= | grep -Fx "${executable}" > /dev/null && return 0
        fi
        sleep 0.2
    done
    print -u2 "The Debug app did not start from ${executable}."
    return 1
}

audit_sources

case "${1:-test}" in
    audit)
        ;;
    lint)
        lint_sources
        ;;
    generate)
        generate_project
        ;;
    build)
        generate_project
        build_app
        ;;
    test)
        lint_sources
        generate_project
        run_tests
        ;;
    reset)
        shift
        reset_local_state "$@"
        ;;
    open)
        generate_project
        build_development_app
        open_development_app
        ;;
    release-tag)
        shift
        exec "${0:A:h}/verify-official-release-tag.sh" "$@"
        ;;
    *)
        print -u2 'usage: run.sh audit|lint|generate|build|test|open|reset [--release]|release-tag'
        exit 64
        ;;
esac
