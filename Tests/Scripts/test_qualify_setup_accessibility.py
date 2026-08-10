import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "Scripts" / "qualify-setup-accessibility.py"
SPEC = importlib.util.spec_from_file_location("qualification", SCRIPT)
assert SPEC is not None
assert SPEC.loader is not None
qualification = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = qualification
SPEC.loader.exec_module(qualification)


class QualificationEvaluatorTests(unittest.TestCase):
    def case(self, identifier: str):
        return next(
            item
            for item in qualification.required_cases()
            if item.identifier == identifier
        )

    def base_evidence(self, case):
        return {
            "status": "passed",
            "evidenceRef": "case-batch-26-a",
            "macOSMajor": case.macos_major,
            "macOSBuild": "25F84",
        }

    def test_required_cases_cover_each_case_on_both_supported_versions(self):
        cases = qualification.required_cases()

        self.assertEqual(len(cases), 16)
        self.assertEqual(
            {case.macos_major for case in cases},
            {"15", "26"},
        )
        self.assertEqual(
            {case.kind for case in cases},
            {
                "guided-setup",
                "management",
                "status-recovery",
                "diagnostics-settings",
                "keyboard-operation",
                "voiceover",
                "visual-state",
                "reduce-motion",
            },
        )

    def test_missing_case_is_inconclusive(self):
        result = qualification.evaluate_case(self.case("voiceover-macos-26"), None)

        self.assertEqual(result["status"], "inconclusive")

    def test_guided_setup_evidence_passes_and_keeps_reference(self):
        case = self.case("guided-setup-macos-26")
        record = self.base_evidence(case)
        record.update(
            {
                "participants": 5,
                "durationsSeconds": [112, 124, 131, 145, 157],
                "builtInPhysicalKeyboard": True,
                "externalPhysicalKeyboard": True,
                "keyboardAssignmentCount": 2,
                "notificationChoiceRecorded": True,
                "reachedReady": True,
                "manualDesignationUsed": False,
            }
        )

        result = qualification.evaluate_case(case, record)

        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["evidenceRef"], "case-batch-26-a")

    def test_guided_setup_non_finite_duration_fails(self):
        case = self.case("guided-setup-macos-26")
        record = self.base_evidence(case)
        record.update(
            {
                "participants": 5,
                "durationsSeconds": [112, 124, float("nan"), 145, 157],
                "builtInPhysicalKeyboard": True,
                "externalPhysicalKeyboard": True,
                "keyboardAssignmentCount": 2,
                "notificationChoiceRecorded": True,
                "reachedReady": True,
                "manualDesignationUsed": False,
            }
        )

        result = qualification.evaluate_case(case, record)

        self.assertEqual(result["status"], "failed")

    def test_accessibility_case_requires_all_checks(self):
        case = self.case("visual-state-macos-15")
        record = self.base_evidence(case)

        incomplete = qualification.evaluate_case(case, record)
        self.assertEqual(incomplete["status"], "inconclusive")

        record.update(
            {
                "visibleFocus": True,
                "sufficientContrast": True,
                "nonColorStatus": True,
            }
        )
        complete = qualification.evaluate_case(case, record)
        self.assertEqual(complete["status"], "passed")

    def test_explicit_failed_accessibility_check_fails_case(self):
        case = self.case("reduce-motion-macos-26")
        record = self.base_evidence(case)
        record["reduceMotion"] = False

        result = qualification.evaluate_case(case, record)

        self.assertEqual(result["status"], "failed")

    def test_wrong_macos_version_fails_case(self):
        case = self.case("management-macos-26")
        record = self.base_evidence(case)
        record["macOSMajor"] = "15"
        record.update({"keyboardOperation": True, "voiceOver": True})

        result = qualification.evaluate_case(case, record)

        self.assertEqual(result["status"], "failed")

    def test_evidence_reader_rejects_forbidden_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.json"
            path.write_text(json.dumps({"keyContent": "redacted"}), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "forbidden field"):
                qualification.read_json(path)

    def test_report_is_inconclusive_when_automated_or_human_evidence_is_missing(self):
        report = qualification.build_qualification_report(
            REPO,
            {},
            [],
            skipped_automated=True,
        )

        self.assertEqual(report["verdict"], "inconclusive")
        self.assertEqual(len(report["requiredCases"]), 16)


if __name__ == "__main__":
    unittest.main()
