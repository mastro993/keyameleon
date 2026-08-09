#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."

audit_sources() {
    local forbidden_pattern='HIDVirtualDevice|seizeDevice\(|kIOHIDRequestTypePostEvent|CGRequestPostEventAccess|DriverKit|Tauri|Electron'
    if rg -n "$forbidden_pattern" Sources project.yml; then
        print -u2 "forbidden non-shell surface found"
        return 1
    fi
}

generate_project() {
    xcodegen generate --spec project.yml
}

run_tests() {
    xcodebuild test \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -destination 'platform=macOS,arch=arm64'
}

build_app() {
    xcodebuild build \
        -project Keyameleon.xcodeproj \
        -scheme Keyameleon \
        -configuration Debug \
        -destination 'platform=macOS,arch=arm64'
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
        open build/Debug/Keyameleon.app
        ;;
    *)
        print -u2 'usage: run.sh audit|generate|build|test|open'
        exit 64
        ;;
esac
