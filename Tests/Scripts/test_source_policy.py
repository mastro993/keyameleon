import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "Sources"
SWIFT_PICKER = re.compile(r"(?<![A-Za-z0-9_])Picker\s*\(")
GITHUB_PAGES_FEED_HOST = "mastro993.github.io/"
LOWERCASE_FEED_PATH = "mastro993.github.io/keyameleon/"
CAPITALIZED_FEED_PATH = "mastro993.github.io/Keyameleon/"
CUSTOM_RULES = (
    "no_observable_object",
    "no_gcd",
    "no_task_sleep_nanoseconds",
    "no_legacy_formatter",
    "no_string_format",
    "no_replacing_occurrences",
    "no_foreground_color",
    "no_swiftui_picker",
    "no_navigation_view",
    "no_tab_item",
    "no_nsscreen_main",
    "no_cfarray_get_value",
)
FORBIDDEN_SOURCE_PATTERNS = (
    ("ObservableObject", re.compile(r"\bObservableObject\b")),
    ("DispatchQueue", re.compile(r"\bDispatchQueue\b")),
    ("Task.sleep(nanoseconds:)", re.compile(r"Task\.sleep\(nanoseconds:")),
    ("DateFormatter", re.compile(r"\bDateFormatter\b")),
    ("String(format:", re.compile(r"String\(format:")),
    ("CFArrayGetValueAtIndex", re.compile(r"CFArrayGetValueAtIndex")),
)


def swift_sources():
    return sorted(SOURCES.rglob("*.swift"))


def uncommented_lines(path):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        yield number, line


class SourcePolicyTests(unittest.TestCase):
    def test_debug_and_release_bundle_identifiers_stay_distinct(self):
        project = (ROOT / "project.yml").read_text(encoding="utf-8")
        app = project.split("  Keyameleon:\n", 1)[1].split("  KeyameleonSwiftTesting:\n", 1)[0]
        identifiers = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER: (\S+)", app))
        self.assertEqual(
            identifiers,
            {"dev.fedemas.keyameleon", "dev.fedemas.keyameleon.debug"},
            "Debug and Release must keep separate bundle IDs (ADR 0008)",
        )

        run_script = (ROOT / "Scripts" / "run.sh").read_text(encoding="utf-8")
        debug = re.search(r"^BUNDLE_ID='([^']+)'", run_script, re.MULTILINE)
        release = re.search(r"^RELEASE_BUNDLE_ID='([^']+)'", run_script, re.MULTILINE)
        self.assertIsNotNone(debug)
        self.assertIsNotNone(release)
        self.assertEqual(debug.group(1), "dev.fedemas.keyameleon.debug")
        self.assertEqual(release.group(1), "dev.fedemas.keyameleon")
        self.assertNotEqual(debug.group(1), release.group(1))

    def test_only_the_release_imports_the_legacy_store(self):
        identity = (ROOT / "Sources" / "App" / "AppBuildIdentity.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn("var importsLegacyStore: Bool", identity)
        self.assertRegex(
            identity,
            r"var importsLegacyStore: Bool \{\s*self == \.release\s*\}",
        )

    def test_sparkle_feed_url_uses_the_lowercase_github_pages_path(self):
        files = [
            ROOT / "project.yml",
            ROOT / "Sources" / "App" / "Info.plist",
            ROOT / "Sources" / "Features" / "About" / "UpdatePolicy.swift",
            ROOT / "Scripts" / "write-release-evidence.sh",
        ]
        for path in files:
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertNotIn(CAPITALIZED_FEED_PATH, text)
                if GITHUB_PAGES_FEED_HOST in text:
                    self.assertIn(LOWERCASE_FEED_PATH, text)

    def test_settings_and_setup_use_popup_picker_not_swiftui_picker(self):
        hits = []
        for path in swift_sources():
            for number, line in uncommented_lines(path):
                if SWIFT_PICKER.search(line):
                    hits.append(f"{path.relative_to(ROOT)}:{number}:{line.strip()}")
        self.assertEqual(
            hits,
            [],
            "SwiftUI Picker hides the System Settings pop-up box at rest; use PopUpPicker",
        )

        input_source_menu = (
            ROOT / "Sources" / "Features" / "Shared" / "InputSourceMenu.swift"
        ).read_text(encoding="utf-8")
        general = (
            ROOT / "Sources" / "Features" / "Configuration" / "GeneralSettingsPane.swift"
        ).read_text(encoding="utf-8")
        self.assertIn("PopUpPicker(", input_source_menu)
        self.assertIn("PopUpPicker(", general)

    def test_hosted_tests_skip_live_surfaces_and_sparkle(self):
        source = (ROOT / "Sources" / "App" / "ApplicationDelegate.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn('environment["XCTestConfigurationFilePath"] != nil', source)
        self.assertIn('environment["XCTestBundlePath"] != nil', source)
        self.assertIn("startsUpdaterOnLaunch: !isHostedUnitTest", source)
        self.assertIn("startsApplicationSurfaceOnLaunch: !isHostedUnitTest", source)

    def test_input_monitoring_relaunch_is_a_process_argument(self):
        recovery = (
            ROOT / "Sources" / "Features" / "ActivityTriggeredSwitching"
            / "InputMonitoringRecovery.swift"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'static let relaunchArgument = "--relaunched-for-input-monitoring"',
            recovery,
        )
        self.assertIn("launchArguments.contains(Self.relaunchArgument)", recovery)
        self.assertNotIn(
            "UserDefaults",
            recovery,
            "A saved relaunch flag can fire on a later manual launch",
        )

    def test_forbidden_agent_patterns_are_absent_from_sources(self):
        hits = []
        for path in swift_sources():
            for number, line in uncommented_lines(path):
                for name, pattern in FORBIDDEN_SOURCE_PATTERNS:
                    if pattern.search(line):
                        hits.append(
                            f"{name}: {path.relative_to(ROOT)}:{number}:{line.strip()}"
                        )
        self.assertEqual(hits, [])

    def test_swiftlint_encodes_the_agent_antipatterns(self):
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        for rule in CUSTOM_RULES:
            with self.subTest(rule=rule):
                self.assertIn(f"{rule}:", configuration)

    def test_safety_audit_still_rejects_cfarray_element_access(self):
        run_script = (ROOT / "Scripts" / "run.sh").read_text(encoding="utf-8")
        self.assertIn("CFArrayGetValueAtIndex", run_script)
        self.assertIn("--include='*.swift'", run_script)

    def test_ci_runs_these_policy_tests_on_linux(self):
        workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("test_source_policy.py", workflow)
        self.assertRegex(workflow, r"(?m)^  policy:")


if __name__ == "__main__":
    unittest.main()
