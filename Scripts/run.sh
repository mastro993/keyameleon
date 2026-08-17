#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "${script_dir}/.."

DERIVED_DATA_PATH="${PWD}/build"
PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug"

audit_sources() {
    local forbidden_pattern='HIDVirtualDevice|IOHIDUserDevice|IOHIDEventSystem|IOHIDPostEvent|IOHIDEvent|seizeDevice[[:space:]]*\(|kIOHIDRequestTypePostEvent|CGEvent(Post|Create|Tap)?|CGRequest(Post|Preflight)EventAccess|CGS[A-Za-z]|sendEvent[[:space:]]*\(|NSEvent[[:space:]]*\.[[:space:]]*(keyEvent|mouseEvent)|URLSession|URLRequest|NSURLConnection|URLProtocol|uploadTask|dataTask|Analytics|Telemetry|Sentry|Crashlytics|MetricKit|PLCrashReporter|diagnosticUpload|crashReportUpload|print[[:space:]]*\(|NSLog[[:space:]]*\(|os_log[[:space:]]*\('
    if grep -REn "$forbidden_pattern" Sources Tests project.yml; then
        print -u2 "forbidden source surface found"
        return 1
    fi

    local diagnostic_paths=(
        Sources/Domain/DiagnosticData.swift
        Sources/App/DiagnosticDataService.swift
        Sources/App/DiagnosticDataStore.swift
        Sources/UI/DiagnosticBundleReviewView.swift
    )
    local prohibited_data_path='PhysicalKeyboardEvent|PhysicalKeyboardEventKind|KeyContent|rawReport|interpretedText|modifierState'
    if grep -REn "$prohibited_data_path" "${diagnostic_paths[@]}"; then
        print -u2 "prohibited Key Content path found"
        return 1
    fi
}

audit_all() {
    audit_sources
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
    xcodegen generate --spec project.yml
    write_modern_workspace_settings
    neutralize_legacy_user_build_locations
}

# Kill leftover Keyameleon processes whose executable is under derived data.
# Does not kill an Official Release or `open` instance outside ./build.
kill_leftover_derived_data_keyameleon() {
    local pid command
    /bin/ps -axww -o pid=,command= | while read -r pid command; do
        case "${command}" in
            "${DERIVED_DATA_PATH}/"*/Keyameleon.app/*)
                kill "${pid}" 2>/dev/null || true
                ;;
        esac
    done
}

run_tests() {
    # Build once. Run the app-driving lifecycle test before hosted test bundles
    # so a delayed UI runner cannot hold completed product tests for 30 minutes.
    xcodebuild build-for-testing \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${DERIVED_DATA_PATH}"

    xcodebuild test-without-building \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -only-testing:KeyameleonUITests \
        -derivedDataPath "${DERIVED_DATA_PATH}"
    kill_leftover_derived_data_keyameleon

    xcodebuild test-without-building \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -skip-testing:KeyameleonUITests \
        -derivedDataPath "${DERIVED_DATA_PATH}"
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
            | awk -F '"' '/Apple Development:/{ print $2; exit }'
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

audit_all

case "${1:-test}" in
    audit)
        ;;
    generate)
        generate_project
        ;;
    build)
        generate_project
        build_app
        ;;
    test)
        generate_project
        run_tests
        ;;
    open)
        generate_project
        build_development_app
        open "${PRODUCTS_PATH}/Keyameleon.app"
        ;;
    release-tag)
        shift
        exec "${0:A:h}/verify-official-release-tag.sh" "$@"
        ;;
    *)
        print -u2 'usage: run.sh audit|generate|build|test|open|release-tag'
        exit 64
        ;;
esac
