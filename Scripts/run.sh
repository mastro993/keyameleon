#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "${script_dir}/.."

DERIVED_DATA_PATH="${PWD}/build"
PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug"

audit_sources() {
    local forbidden_pattern='HIDVirtualDevice|IOHIDUserDevice|IOHIDEventSystem|IOHIDPostEvent|IOHIDEvent|seizeDevice[[:space:]]*\(|kIOHIDRequestTypePostEvent|CGEvent(Post|Create|Tap)?|CGRequest(Post|Preflight)EventAccess|CGS[A-Za-z]|DriverKit|Tauri|Electron|sendEvent[[:space:]]*\(|NSEvent[[:space:]]*\.[[:space:]]*(keyEvent|mouseEvent)|URLSession|URLRequest|NSURLConnection|URLProtocol|uploadTask|dataTask|Analytics|Telemetry|Sentry|Crashlytics|MetricKit|PLCrashReporter|diagnosticUpload|crashReportUpload|print[[:space:]]*\(|NSLog[[:space:]]*\(|os_log[[:space:]]*\('
    if grep -REn "$forbidden_pattern" Sources Tests project.yml; then
        print -u2 "forbidden source surface found"
        return 1
    fi

    local diagnostic_paths=(
        Sources/Domain/KeyameleonDiagnosticData.swift
        Sources/App/KeyameleonDiagnosticDataService.swift
        Sources/App/KeyameleonDiagnosticDataStore.swift
        Sources/UI/KeyameleonDiagnosticBundleReviewView.swift
    )
    local prohibited_data_path='PhysicalKeyboardEvent|PhysicalKeyboardEventKind|KeyContent|rawReport|interpretedText|modifierState'
    if grep -REn "$prohibited_data_path" "${diagnostic_paths[@]}"; then
        print -u2 "prohibited Key Content path found"
        return 1
    fi
}

audit_dependencies() {
    python3 - "$PWD/project.yml" "$PWD/Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" <<'PY'
import json
import re
import sys
from pathlib import Path

project_path, resolved_path = map(Path, sys.argv[1:])
project = project_path.read_text(encoding="utf-8")

package_section = project.split("packages:", 1)[1].split("settings:", 1)[0]
declared_packages = set(re.findall(r"^  ([A-Za-z0-9_-]+):\s*$", package_section, re.MULTILINE))
package_dependencies = set(re.findall(r"^\s+- package: ([A-Za-z0-9_-]+)\s*$", project, re.MULTILINE))
sdk_dependencies = set(re.findall(r"^\s+- sdk: ([A-Za-z0-9_.]+)\s*$", project, re.MULTILINE))

allowed_packages = {"Sparkle"}
allowed_sdks = {
    "AppKit.framework",
    "Carbon.framework",
    "CoreHID.framework",
    "CryptoKit.framework",
    "IOKit.framework",
    "Security.framework",
    "ServiceManagement.framework",
    "SwiftData.framework",
    "SwiftUI.framework",
    "UserNotifications.framework",
}

errors = []
if declared_packages != allowed_packages:
    errors.append(f"unexpected package declarations: {sorted(declared_packages - allowed_packages)}")
if package_dependencies != allowed_packages:
    errors.append(f"unexpected package dependencies: {sorted(package_dependencies - allowed_packages)}")
if not sdk_dependencies <= allowed_sdks:
    errors.append(f"unexpected SDK dependencies: {sorted(sdk_dependencies - allowed_sdks)}")

resolved = json.loads(resolved_path.read_text(encoding="utf-8"))
resolved_identities = {pin["identity"] for pin in resolved.get("pins", [])}
if resolved_identities != {"sparkle"}:
    errors.append(f"unexpected resolved dependencies: {sorted(resolved_identities - {'sparkle'})}")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(1)
PY
}

audit_all() {
    audit_sources
    audit_dependencies
}

generate_project() {
    xcodegen generate --spec project.yml
}

run_tests() {
    python3 -m unittest discover -s Tests/Scripts -p 'test_*.py'
    # The menu-bar app and hosted macOS test bundles must not launch in parallel.
    xcodebuild test \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64' \
        -parallel-testing-enabled NO \
        -derivedDataPath "${DERIVED_DATA_PATH}"
}

build_app() {
    xcodebuild build \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -configuration Debug \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "${DERIVED_DATA_PATH}"
}

audit_all

case "${1:-test}" in
    audit)
        ;;
    qualify)
        shift
        exec "${script_dir}/qualification.sh" "$@"
        ;;
    qualify-setup-accessibility)
        shift
        exec python3 "${script_dir}/qualify-setup-accessibility.py" "$@"
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
        build_app
        open "${PRODUCTS_PATH}/Keyameleon.app"
        ;;
    release-tag)
        shift
        exec "${0:A:h}/verify-official-release-tag.sh" "$@"
        ;;
    *)
        print -u2 'usage: run.sh audit|qualify|qualify-setup-accessibility|generate|build|test|open|release-tag'
        exit 64
        ;;
esac
