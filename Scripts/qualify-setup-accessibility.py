#!/usr/bin/env python3
"""Run automated gates and evaluate human setup/accessibility evidence."""

from __future__ import annotations

import argparse
import json
import math
import platform
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SUPPORTED_MACOS = ("15", "26")
PASS = "passed"
FAIL = "failed"
INCONCLUSIVE = "inconclusive"
VALID_STATUSES = {PASS, FAIL, INCONCLUSIVE}
EVIDENCE_REFERENCE_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
MACOS_BUILD_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
CASE_REQUIRED_EVIDENCE_FIELDS = {
    "management": ("keyboardOperation", "voiceOver"),
    "status-recovery": ("keyboardOperation", "voiceOver", "switchingStatusChanges"),
    "diagnostics-settings": ("keyboardOperation", "voiceOver"),
    "keyboard-operation": ("keyboardOperation",),
    "voiceover": ("voiceOverNamesValuesActions", "voiceOverStateChanges"),
    "visual-state": ("visibleFocus", "sufficientContrast", "nonColorStatus"),
    "reduce-motion": ("reduceMotion",),
}


@dataclass(frozen=True)
class QualificationCase:
    identifier: str
    title: str
    kind: str
    macos_major: str


def required_cases() -> list[QualificationCase]:
    cases: list[QualificationCase] = []
    case_kinds = (
        ("guided-setup", "Guided setup timed journey"),
        ("management", "Physical Keyboard management journey"),
        ("status-recovery", "Switching Status and recovery journey"),
        ("diagnostics-settings", "Diagnostic Bundle and General Settings journey"),
        ("keyboard-operation", "Full keyboard operation"),
        ("voiceover", "VoiceOver names, values, actions, and state changes"),
        ("visual-state", "Visible focus, contrast, and non-color status"),
        ("reduce-motion", "Reduce Motion behavior"),
    )
    for macos_major in SUPPORTED_MACOS:
        for kind, title in case_kinds:
            cases.append(
                QualificationCase(
                    identifier=f"{kind}-macos-{macos_major}",
                    title=f"{title} on macOS {macos_major}",
                    kind=kind,
                    macos_major=macos_major,
                )
            )
    return cases


FORBIDDEN_EVIDENCE_KEYS = {
    "keycontent",
    "keyboardassignment",
    "physicalkeyboardidentity",
    "physicalkeyboardname",
    "serial",
    "serialnumber",
    "inputsource",
    "inputsourceidentifier",
    "customphysicalkeyboardname",
    "locationidentifier",
    "username",
    "applicationname",
}


def normalized_key(value: str) -> str:
    return "".join(character for character in value.lower() if character.isalnum())


def is_safe_evidence_reference(value: Any) -> bool:
    return (
        isinstance(value, str)
        and EVIDENCE_REFERENCE_PATTERN.fullmatch(value) is not None
    )


def is_number(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def fail_case(result: dict[str, Any], reason: str) -> dict[str, Any]:
    result["status"] = FAIL
    result["reason"] = reason
    return result


def find_forbidden_key(value: Any) -> str | None:
    if isinstance(value, dict):
        for key, child in value.items():
            if normalized_key(str(key)) in FORBIDDEN_EVIDENCE_KEYS:
                return str(key)
            found = find_forbidden_key(child)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_forbidden_key(child)
            if found is not None:
                return found
    return None


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"could not read evidence JSON: {error}") from error
    if not isinstance(value, dict):
        raise ValueError("evidence JSON root must be an object")
    forbidden_key = find_forbidden_key(value)
    if forbidden_key is not None:
        raise ValueError(f"evidence contains forbidden field: {forbidden_key}")
    return value


def command_output(command: list[str], repo: Path) -> str | None:
    try:
        result = subprocess.run(
            command,
            cwd=repo,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def candidate_metadata(repo: Path) -> dict[str, Any]:
    return {
        "gitCommit": command_output(["git", "rev-parse", "HEAD"], repo),
        "sourceTag": command_output(
            ["git", "describe", "--tags", "--exact-match", "HEAD"], repo
        ),
        "macOSProductVersion": command_output(["sw_vers", "-productVersion"], repo),
        "macOSBuild": command_output(["sw_vers", "-buildVersion"], repo),
        "architecture": platform.machine(),
    }


def run_gate(
    identifier: str,
    command: list[str],
    repo: Path,
    logs_directory: Path,
) -> dict[str, Any]:
    log_path = logs_directory / f"{identifier}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    command_line = " ".join(command)
    try:
        with log_path.open("w", encoding="utf-8") as log:
            log.write(f"$ {command_line}\n\n")
            result = subprocess.run(
                command,
                cwd=repo,
                check=False,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
            )
    except OSError as error:
        log_path.write_text(f"{command_line}\n\n{error}\n", encoding="utf-8")
        return {
            "id": identifier,
            "status": INCONCLUSIVE,
            "reason": "Required command was unavailable.",
            "log": f"logs/{log_path.name}",
        }

    return {
        "id": identifier,
        "status": PASS if result.returncode == 0 else FAIL,
        "reason": "Command completed successfully."
        if result.returncode == 0
        else "Command failed.",
        "exitCode": result.returncode,
        "log": f"logs/{log_path.name}",
    }


def safe_evidence_summary(record: dict[str, Any]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for key in (
        "macOSMajor",
        "macOSBuild",
        "participants",
        "keyboardAssignmentCount",
        "builtInPhysicalKeyboard",
        "externalPhysicalKeyboard",
        "notificationChoiceRecorded",
        "reachedReady",
        "manualDesignationUsed",
        "keyboardOperation",
        "voiceOver",
        "switchingStatusChanges",
        "voiceOverNamesValuesActions",
        "voiceOverStateChanges",
        "visibleFocus",
        "sufficientContrast",
        "nonColorStatus",
        "reduceMotion",
    ):
        if key in record:
            summary[key] = record[key]
    durations = record.get("durationsSeconds")
    if isinstance(durations, list) and durations:
        numeric_durations = [value for value in durations if is_number(value)]
        if numeric_durations:
            summary["durationCount"] = len(numeric_durations)
            summary["maxDurationSeconds"] = max(numeric_durations)
    return summary


def evaluate_case(case: QualificationCase, record: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": case.identifier,
        "title": case.title,
        "required": True,
        "status": INCONCLUSIVE,
        "reason": "Evidence unavailable or not supplied.",
    }

    if record is None:
        return result
    if not isinstance(record, dict):
        result["reason"] = "Evidence record must be an object."
        return result

    status = record.get("status")
    if status not in VALID_STATUSES:
        result["reason"] = "Evidence status is missing or invalid."
        return result

    result["evidenceProvided"] = True
    if status == FAIL:
        result["status"] = FAIL
        result["reason"] = "Evidence reports a failed required case."
        return result
    if status == INCONCLUSIVE:
        result["reason"] = "Evidence reports an unavailable or unrun case."
        return result

    evidence_reference = record.get("evidenceRef")
    if not is_safe_evidence_reference(evidence_reference):
        result["reason"] = "Passed case has no safe evidence reference."
        return result
    result["evidenceRef"] = evidence_reference

    if not isinstance(record.get("macOSMajor"), str) or not isinstance(
        record.get("macOSBuild"), str
    ):
        result["reason"] = "Case evidence has no macOS version and build."
        return result
    if record["macOSMajor"] != case.macos_major:
        return fail_case(result, "Case evidence uses the wrong macOS version.")
    if MACOS_BUILD_PATTERN.fullmatch(record["macOSBuild"]) is None:
        result["reason"] = "Case evidence has an invalid macOS build."
        return result

    if case.kind == "guided-setup":
        return evaluate_guided_setup_case(result, record)

    required_fields = CASE_REQUIRED_EVIDENCE_FIELDS.get(case.kind, ())
    missing_fields = [field for field in required_fields if field not in record]
    if missing_fields:
        result["reason"] = "Accessibility evidence is incomplete."
        result["missingFields"] = missing_fields
        return result
    invalid_fields = [
        field for field in required_fields if type(record[field]) is not bool
    ]
    if invalid_fields:
        result["reason"] = "Accessibility evidence has invalid measurements."
        result["invalidFields"] = invalid_fields
        return result
    failed_fields = [field for field in required_fields if record[field] is False]
    if failed_fields:
        return fail_case(result, "A required accessibility check failed.")

    result["status"] = PASS
    result["reason"] = "Evidence reference supplied."
    result["evidence"] = safe_evidence_summary(record)
    return result


def evaluate_guided_setup_case(
    result: dict[str, Any], record: dict[str, Any]
) -> dict[str, Any]:
    required_fields = (
        "participants",
        "durationsSeconds",
        "builtInPhysicalKeyboard",
        "externalPhysicalKeyboard",
        "keyboardAssignmentCount",
        "notificationChoiceRecorded",
        "reachedReady",
        "manualDesignationUsed",
    )
    missing_fields = [field for field in required_fields if field not in record]
    if missing_fields:
        result["reason"] = "Timed journey evidence is incomplete."
        result["missingFields"] = missing_fields
        return result

    participants = record["participants"]
    durations = record["durationsSeconds"]
    if type(participants) is not int or not isinstance(durations, list):
        result["reason"] = "Timed journey evidence has invalid measurements."
        return result
    if len(durations) < participants or any(
        not is_number(value) for value in durations
    ):
        return fail_case(result, "Timed journey duration evidence is invalid.")
    if participants < 5 or len(durations) < 5:
        return fail_case(
            result, "Fewer than five Multilingual Professionals were measured."
        )
    if any(value >= 180 or value < 0 for value in durations):
        return fail_case(result, "A timed setup journey reached or exceeded 3 minutes.")
    if record["builtInPhysicalKeyboard"] is not True:
        return fail_case(result, "Built-in Physical Keyboard was not used.")
    if record["externalPhysicalKeyboard"] is not True:
        return fail_case(result, "External Physical Keyboard was not used.")
    if type(record["keyboardAssignmentCount"]) is not int or record[
        "keyboardAssignmentCount"
    ] < 2:
        return fail_case(result, "Two Keyboard Assignments were not created.")
    if record["notificationChoiceRecorded"] is not True:
        return fail_case(result, "Notification choice was not recorded.")
    if record["reachedReady"] is not True:
        return fail_case(result, "Setup did not reach Ready.")
    if record["manualDesignationUsed"] is not False:
        return fail_case(
            result, "Manual Physical Keyboard Designation entered timed journey."
        )

    result["status"] = PASS
    result["reason"] = "Timed journey evidence meets required bounds."
    result["evidence"] = safe_evidence_summary(record)
    return result


def build_qualification_report(
    repo: Path,
    evidence: dict[str, Any],
    automated_gates: list[dict[str, Any]],
    skipped_automated: bool,
) -> dict[str, Any]:
    evidence_cases = evidence.get("cases", {})
    if evidence_cases is None:
        evidence_cases = {}
    if not isinstance(evidence_cases, dict):
        raise ValueError("evidence field 'cases' must be an object keyed by case ID")

    definitions = required_cases()
    known_ids = {case.identifier for case in definitions}
    unknown_ids = sorted(set(evidence_cases) - known_ids)
    if unknown_ids:
        raise ValueError(f"evidence contains unknown case IDs: {', '.join(unknown_ids)}")

    cases = [
        evaluate_case(case, evidence_cases.get(case.identifier))
        for case in definitions
    ]
    all_gates = list(automated_gates)
    if skipped_automated:
        all_gates.append(
            {
                "id": "automated-gates",
                "status": INCONCLUSIVE,
                "reason": "Automated gates were skipped.",
            }
        )

    statuses = [case["status"] for case in cases] + [
        gate["status"] for gate in all_gates
    ]
    verdict = (
        FAIL
        if FAIL in statuses
        else INCONCLUSIVE
        if INCONCLUSIVE in statuses
        else PASS
    )
    return {
        "schemaVersion": 1,
        "issue": 19,
        "product": "Keyameleon",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "candidate": candidate_metadata(repo),
        "automatedGates": all_gates,
        "requiredCases": cases,
        "verdict": verdict,
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Qualify Keyameleon Guided setup and accessibility gates."
    )
    repo = Path(__file__).resolve().parents[1]
    parser.add_argument(
        "--evidence",
        type=Path,
        help="JSON file with human qualification evidence.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo / "build/qualification/setup-accessibility.json",
        help="Qualification report path.",
    )
    parser.add_argument(
        "--skip-automated",
        action="store_true",
        help="Do not run build, test, or source audit gates.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    repo = Path(__file__).resolve().parents[1]
    output_path = arguments.output.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        evidence = read_json(arguments.evidence) if arguments.evidence else {}
        automated_gates: list[dict[str, Any]] = []
        if not arguments.skip_automated:
            logs_directory = output_path.parent / "logs"
            for identifier, command in (
                ("source-audit", ["./Scripts/run.sh", "audit"]),
                ("application-build", ["./Scripts/run.sh", "build"]),
                ("automated-test-suite", ["./Scripts/run.sh", "test"]),
            ):
                automated_gates.append(
                    run_gate(identifier, command, repo, logs_directory)
                )
        report = build_qualification_report(
            repo,
            evidence,
            automated_gates,
            arguments.skip_automated,
        )
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 64

    output_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"{output_path}: {report['verdict']}")
    return {PASS: 0, FAIL: 1, INCONCLUSIVE: 2}[report["verdict"]]


if __name__ == "__main__":
    raise SystemExit(main())
