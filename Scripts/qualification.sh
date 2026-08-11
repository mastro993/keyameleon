#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
cd "$repo_root"

suite_runs="${QUALIFICATION_SUITE_RUNS:-10}"
supported_macos_versions="${QUALIFICATION_SUPPORTED_MACOS_VERSIONS:-15 26}"
evidence_dir="${QUALIFICATION_EVIDENCE_DIR:-${repo_root}/.scratch/qualification}"
evidence_path="${QUALIFICATION_EVIDENCE_PATH:-${evidence_dir}/qualification-evidence.json}"

if [[ ! "$suite_runs" =~ ^[1-9][0-9]*$ ]]; then
    echo "QUALIFICATION_SUITE_RUNS must be a positive integer" >&2
    exit 64
fi

mkdir -p "$evidence_dir"
run_dir="$(mktemp -d "${evidence_dir}/run.XXXXXX")"
metadata_path="${run_dir}/cases.tsv"
: > "$metadata_path"

record_case() {
    local case_id="$1"
    local status="$2"
    local detail="$3"

    printf '%s\t%s\t%s\n' "$case_id" "$status" "$detail" >> "$metadata_path"
}

run_case() {
    local case_id="$1"
    shift
    local log_path="${run_dir}/${case_id}.log"

    if "$@" >"$log_path" 2>&1; then
        record_case "$case_id" "pass" "Command completed"
        return 0
    fi

    record_case "$case_id" "fail" "Command failed; local case log retained"
    echo "qualification case failed: ${case_id}" >&2
    return 0
}

audit_network_and_crash_surfaces() {
    local network_pattern='URLSession|URLRequest|NSURLConnection|URLProtocol|uploadTask|dataTask|diagnostic[[:space:]]+(upload|endpoint|request)|crash[[:space:]]+(upload|endpoint|request)|Sentry|Crashlytics|MetricKit|PLCrashReporter'
    if grep -E -n -i "$network_pattern" -R Sources; then
        echo "diagnostic or crash network surface found" >&2
        return 1
    fi
}

audit_qualification_test_contract() {
    grep -E -q '100_000' Tests/SwiftTesting/KeyameleonQualificationTests.swift
    grep -E -q 'SENTINEL_IDENTITY|SENTINEL_SERIAL|KeyContentPayload' Tests/SwiftTesting/KeyameleonQualificationTests.swift
}

audit_console_output() {
    local sentinel_pattern='SENTINEL_IDENTITY|SENTINEL_SERIAL|KeyContentPayload|physical-identity-sensitive-sentinel|Key Content sensitive sentinel|macOS crash report sensitive sentinel|/Users/sensitive-sentinel'
    local log_path
    for log_path in "${run_dir}"/*.log; do
        [[ -f "$log_path" ]] || continue
        if grep -E -n "$sentinel_pattern" "$log_path"; then
            echo "controlled Key Content sentinel found in console output" >&2
            return 1
        fi
    done
}

audit_files() {
    local sentinel_pattern='SENTINEL_IDENTITY|SENTINEL_SERIAL|KeyContentPayload|physical-identity-sensitive-sentinel|Key Content sensitive sentinel|macOS crash report sensitive sentinel|/Users/sensitive-sentinel'
    local app_path="${repo_root}/build/Build/Products/Debug/Keyameleon.app"
    local scan_path
    local scan_paths=()

    # Test bundles contain the sentinel fixtures by design. Scan generated
    # product files and exclude this gate's own logs and audit metadata.
    while IFS= read -r -d '' scan_path; do
        case "$scan_path" in
            *.log|*/binary-surfaces.txt|*/cases.tsv) continue ;;
        esac
        scan_paths+=("$scan_path")
    done < <(find "$run_dir" -type f -print0)

    if [[ -d "${app_path}/Contents" ]]; then
        while IFS= read -r -d '' scan_path; do
            scan_paths+=("$scan_path")
        done < <(find "${app_path}/Contents" -type f ! -path "${app_path}/Contents/PlugIns/*" -print0)
    fi

    if ((${#scan_paths[@]} > 0)) && grep -a -E -n "$sentinel_pattern" "${scan_paths[@]}"; then
        echo "controlled Key Content sentinel found in generated files" >&2
        return 1
    fi
}

audit_binary() {
    local app_path="${repo_root}/build/Build/Products/Debug/Keyameleon.app"
    local surface_path="${run_dir}/binary-surfaces.txt"
    local binary_paths=(
        "${app_path}/Contents/MacOS/Keyameleon"
        "${app_path}/Contents/MacOS/Keyameleon.debug.dylib"
        "${app_path}/Contents/MacOS/__preview.dylib"
    )

    if [[ ! -d "$app_path" ]]; then
        echo "Keyameleon app not found" >&2
        return 1
    fi

    : > "$surface_path"
    local binary_path
    for binary_path in "${binary_paths[@]}"; do
        [[ -f "$binary_path" ]] || continue
        {
            printf '\n--- %s ---\n' "$(basename "$binary_path")"
            otool -L "$binary_path"
            nm -u "$binary_path" 2>/dev/null || true
            strings -a "$binary_path"
        } >> "$surface_path"
    done

    [[ -s "$surface_path" ]] || {
        echo "Keyameleon app binaries not found" >&2
        return 1
    }

    local forbidden_pattern='HIDVirtualDevice|IOHIDUserDevice|IOHIDEventSystem|IOHIDPostEvent|seizeDevice|kIOHIDRequestTypePostEvent|CGEvent(Post|Create|Tap)?|CGRequest(Post|Preflight)EventAccess|DriverKit|Tauri|Electron|sendEvent|NSEvent.*(keyEvent|mouseEvent)|Sentry|Crashlytics|MetricKit|PLCrashReporter|diagnosticUpload|crashReportUpload|Analytics|Telemetry'
    if grep -E -n -i "$forbidden_pattern" "$surface_path"; then
        echo "forbidden binary surface found" >&2
        return 1
    fi

    local sentinel_pattern='SENTINEL_IDENTITY|SENTINEL_SERIAL|KeyContentPayload|physical-identity-sensitive-sentinel|Key Content sensitive sentinel|macOS crash report sensitive sentinel|/Users/sensitive-sentinel'
    if grep -E -n "$sentinel_pattern" "$surface_path"; then
        echo "controlled Key Content sentinel found in binary" >&2
        return 1
    fi
}

run_case "source-dependency-audit" "${script_dir}/run.sh" audit
run_case "build" "${script_dir}/run.sh" build
run_case "network-crash-surface-audit" audit_network_and_crash_surfaces
run_case "qualification-test-contract" audit_qualification_test_contract
run_case "binary-audit" audit_binary

for run_number in $(seq 1 "$suite_runs"); do
    case_id="suite-${run_number}"
    run_case "$case_id" env KEYAMELEON_SERIAL_TESTS=1 "${script_dir}/run.sh" test
done

run_case "console-output-sentinel-audit" audit_console_output
run_case "generated-file-sentinel-audit" audit_files

current_macos_version="$(sw_vers -productVersion)"
current_macos_major="${current_macos_version%%.*}"
current_macos_build="$(sw_vers -buildVersion)"
current_architecture="$(uname -m)"

read -r -a required_macos_majors <<< "$supported_macos_versions"
current_is_required=false
for required_major in "${required_macos_majors[@]}"; do
    if [[ "$required_major" == "$current_macos_major" ]]; then
        current_is_required=true
        break
    fi
done

if [[ "$current_is_required" != true ]]; then
    record_case "macos-platform" "inconclusive" "Current host is outside configured supported macOS majors"
elif [[ "${#required_macos_majors[@]}" -gt 1 ]]; then
    record_case "macos-platform" "inconclusive" "Run same gate on every configured supported macOS major"
else
    record_case "macos-platform" "pass" "Current supported macOS major covered"
fi

python3 - "$evidence_path" "$metadata_path" "$current_macos_version" "$current_macos_build" "$current_architecture" "$suite_runs" "$supported_macos_versions" <<'PY'
import json
import sys
from pathlib import Path

(
    evidence_path,
    metadata_path,
    macos_version,
    macos_build,
    architecture,
    suite_runs,
    supported_macos_versions,
) = sys.argv[1:]

cases = []
for line in Path(metadata_path).read_text(encoding="utf-8").splitlines():
    case_id, status, detail = line.split("\t", 2)
    cases.append({"id": case_id, "status": status, "detail": detail})

statuses = {case["status"] for case in cases}
if "fail" in statuses:
    verdict = "fail"
elif "inconclusive" in statuses:
    verdict = "inconclusive"
else:
    verdict = "pass"

evidence = {
    "schemaVersion": 1,
    "product": "Keyameleon",
    "qualification": "automated",
    "verdict": verdict,
    "host": {
        "architecture": architecture,
        "macOSMajorVersion": macos_version.split(".", 1)[0],
        "macOSBuild": macos_build,
    },
    "configuredSupportedMacOSMajors": supported_macos_versions.split(),
    "completeSuiteRuns": int(suite_runs),
    "deterministicStressEventCount": 100_000,
    "cases": cases,
}

path = Path(evidence_path)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(f"qualification verdict: {verdict}")
print(path)
PY

verdict="$(python3 - "$evidence_path" <<'PY'
import json
import sys
from pathlib import Path

print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["verdict"])
PY
)"

case "$verdict" in
    pass)
        exit 0
        ;;
    fail)
        exit 1
        ;;
    inconclusive)
        exit 2
        ;;
esac
