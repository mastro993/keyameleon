#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "${script_dir}/.."

DERIVED_DATA_PATH="${PWD}/build"
PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug"
BUNDLE_ID='dev.fedemas.keyameleon'
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
        Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching.swift
        Sources/Features/Shared/SetupModel.swift
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

    if grep -REn 'CFArrayGetValueAtIndex' Sources Tests; then
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
    local pid command
    /bin/ps -axww -o pid=,command= | while read -r pid command; do
        case "${command}" in
            "${PRODUCTS_PATH}/Keyameleon.app/Contents/MacOS/Keyameleon"|\
            "${PRODUCTS_PATH}/Keyameleon.app/Contents/MacOS/Keyameleon "*)
                kill "${pid}" 2>/dev/null || true
                ;;
        esac
    done
}

run_tests() {
    local script
    for script in \
        Scripts/official-release-notes.sh \
        Scripts/publish-release-pages.sh \
        Scripts/verify-official-release-tag.sh \
        Scripts/write-release-evidence.sh; do
        bash -n "$script" || return $?
    done
    zsh -n Scripts/official-release.sh
    python3 -m unittest discover -s Tests/Scripts -p 'test_*.py'
    kill_leftover_derived_data_keyameleon

    xcodebuild build-for-testing \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO

    xcodebuild test-without-building \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO
    kill_leftover_derived_data_keyameleon
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

# Prints one "PID<TAB>bundle path" line for each running Keyameleon of this user.
running_keyameleon_apps() {
    /usr/bin/osascript -l JavaScript -e \
        'ObjC.import("AppKit"); $.NSRunningApplication.runningApplicationsWithBundleIdentifier("dev.fedemas.keyameleon").js.map(app => app.processIdentifier + "\t" + app.bundleURL.path.js).join("\n")'
}

wait_until_no_keyameleon_runs() {
    local attempt running
    for (( attempt = 0; attempt < 50; attempt++ )); do
        running="$(running_keyameleon_apps)" || return 1
        [[ -z "${running}" ]] && return 0
        sleep 0.2
    done
    print -u2 'A Keyameleon process is still running.'
    return 1
}

# Prints every bundle path LaunchServices has registered for the bundle ID.
# macOS's Quit & Reopen (offered after an Input Monitoring change) relaunches by
# bundle ID, so with stale copies registered it can open a different Keyameleon.
registered_keyameleon_apps() {
    "${LSREGISTER}" -dump 2>/dev/null | awk '
        /^path:/ { sub(/^path:[[:space:]]+/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); path = $0 }
        /^identifier:[[:space:]]+dev\.fedemas\.keyameleon$/ { print path }
    ' | sort -u
}

# Returns this Mac to a never-installed state for Keyameleon, so the next launch
# is a first run. Quits every running copy, including an installed release.
# The Keychain integrity key stays, as it would after a real uninstall; it only
# signs data this reset deletes.
reset_local_state() {
    local pid bundle app running

    running="$(running_keyameleon_apps)" || return 1
    while IFS=$'\t' read -r pid bundle; do
        [[ -n "${pid}" ]] || continue
        print "Quitting Keyameleon PID ${pid} at ${bundle}"
        kill "${pid}" 2>/dev/null || true
    done <<< "${running}"
    wait_until_no_keyameleon_runs || return 1

    # The next launched copy registers itself again and becomes the one
    # Quit & Reopen finds. Records for deleted copies are never launched.
    registered_keyameleon_apps | while IFS= read -r app; do
        [[ -d "${app}" ]] || continue
        print "Unregistering ${app}"
        if ! "${LSREGISTER}" -u "${app}"; then
            print -u2 "Could not unregister ${app}; Quit & Reopen may still open it."
            return 1
        fi
    done || return 1

    tccutil reset All "${BUNDLE_ID}"
    defaults delete "${BUNDLE_ID}" 2>/dev/null || true
    rm -rf "${HOME}/Library/Application Support/Keyameleon" "${HOME}/Library/Logs/Keyameleon"

    # Before 0.4.6 the store lived at SwiftData's shared default path, and launch
    # copies it into the Keyameleon folder again. Other apps may use that path, so
    # delete it only when Keyameleon's keyboard table is there and every other
    # table is Keyameleon's or Core Data's own. A store that also holds any other
    # table is never edited; the reset fails instead.
    local legacy_store="${HOME}/Library/Application Support/default.store"
    local legacy_store_query="
        SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ZPHYSICALKEYBOARDRECORDMODEL')
            || EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name NOT GLOB 'sqlite_*'
                AND name NOT IN (
                    'ZPHYSICALKEYBOARDRECORDMODEL', 'ZMANUALPHYSICALKEYBOARDDESIGNATIONMODEL',
                    'Z_PRIMARYKEY', 'Z_METADATA', 'Z_MODELCACHE',
                    'ACHANGE', 'ATRANSACTION', 'ATRANSACTIONSTRING'))"
    local legacy_store_tables=''
    if [[ -f "${legacy_store}" ]] \
        && ! legacy_store_tables="$(sqlite3 -readonly "${legacy_store}" "${legacy_store_query}")"; then
        print -u2 "Could not inspect ${legacy_store}, so it was kept. The next launch may copy its keyboards back."
        return 1
    fi
    case "${legacy_store_tables}" in
        10)
            print "Deleting legacy store ${legacy_store}"
            rm -f -- "${legacy_store}" "${legacy_store}-shm" "${legacy_store}-wal"
            ;;
        11)
            print -u2 "${legacy_store} holds Keyameleon's keyboards and another app's data, so it was kept."
            print -u2 'The next launch copies those keyboards back. Remove them by hand for a first run.'
            return 1
            ;;
    esac
    print 'Keyameleon local state reset.'
}

# Replaces only this checkout's Debug app. Any other running Keyameleon, such as an
# installed release, holds the single-instance lock and is never stopped here.
open_development_app() {
    local app="${PRODUCTS_PATH}/Keyameleon.app"
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
        reset_local_state
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
        print -u2 'usage: run.sh audit|lint|generate|build|test|open|reset|release-tag'
        exit 64
        ;;
esac
