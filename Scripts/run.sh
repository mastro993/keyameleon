#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."

DERIVED_DATA_PATH="${PWD}/build"
PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug"

audit_sources() {
    local forbidden_pattern='HIDVirtualDevice|seizeDevice\(|kIOHIDRequestTypePostEvent|CGRequestPostEventAccess|DriverKit|Tauri|Electron'
    if grep -REn "$forbidden_pattern" Sources project.yml; then
        print -u2 "forbidden non-shell surface found"
        return 1
    fi
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

audit_sources

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
        build_app
        open "${PRODUCTS_PATH}/Keyameleon.app"
        ;;
    qualify)
        shift
        exec python3 "${0:A:h}/qualify-setup-accessibility.py" "$@"
        ;;
    release-tag)
        shift
        exec "${0:A:h}/verify-official-release-tag.sh" "$@"
        ;;
    *)
        print -u2 'usage: run.sh audit|generate|build|test|open|qualify|release-tag'
        exit 64
        ;;
esac
