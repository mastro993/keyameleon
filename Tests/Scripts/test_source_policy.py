import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "Sources"
FORM_FEATURE_DIRS = (
    SOURCES / "Features" / "Configuration",
    SOURCES / "Features" / "Onboarding",
    SOURCES / "Features" / "Shared",
    SOURCES / "Features" / "AppAssignments",
)
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
    ("Task.sleep(nanoseconds:)", re.compile(r"Task\.sleep\(\s*nanoseconds:")),
    ("DateFormatter", re.compile(r"\bDateFormatter\b")),
    ("String(format:", re.compile(r"String\(\s*format:")),
    ("CFArrayGetValueAtIndex", re.compile(r"CFArrayGetValueAtIndex")),
)


def swift_sources(root=SOURCES):
    return sorted(root.rglob("*.swift"))


def keep_newlines(chunk):
    return "".join("\n" if character == "\n" else " " for character in chunk)


def blank_non_code(source):
    """Replace Swift comments and string literals with spaces, keeping newlines."""
    out = []
    index = 0
    length = len(source)
    while index < length:
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end == -1:
                out.append(keep_newlines(source[index:]))
                break
            out.append(keep_newlines(source[index:end + 2]))
            index = end + 2
            continue
        if source.startswith("//", index):
            end = source.find("\n", index)
            if end == -1:
                out.append(" " * (length - index))
                break
            out.append(" " * (end - index))
            index = end
            continue
        if source.startswith('"""', index):
            end = source.find('"""', index + 3)
            if end == -1:
                out.append(keep_newlines(source[index:]))
                break
            out.append(keep_newlines(source[index:end + 3]))
            index = end + 3
            continue
        if source[index] in "\"'":
            quote = source[index]
            cursor = index + 1
            while cursor < length:
                if source[cursor] == "\\":
                    cursor += 2
                    continue
                if source[cursor] == quote:
                    cursor += 1
                    break
                cursor += 1
            out.append(keep_newlines(source[index:cursor]))
            index = cursor
            continue
        out.append(source[index])
        index += 1
    return "".join(out)


def line_of(source, offset):
    return source.count("\n", 0, offset) + 1


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
        for directory in FORM_FEATURE_DIRS:
            for path in swift_sources(directory):
                source = path.read_text(encoding="utf-8")
                code = blank_non_code(source)
                for match in SWIFT_PICKER.finditer(code):
                    hits.append(
                        f"{path.relative_to(ROOT)}:{line_of(source, match.start())}"
                    )
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
            source = path.read_text(encoding="utf-8")
            code = blank_non_code(source)
            for name, pattern in FORBIDDEN_SOURCE_PATTERNS:
                for match in pattern.finditer(code):
                    hits.append(
                        f"{name}: {path.relative_to(ROOT)}:{line_of(source, match.start())}"
                    )
        self.assertEqual(hits, [])

    def test_policy_scanner_ignores_comments_and_strings(self):
        ignored = blank_non_code(
            'let note = "DispatchQueue"\n'
            "let value = 1 // avoid DateFormatter here\n"
            "/* CFArrayGetValueAtIndex */\n"
        )
        self.assertIsNone(re.search(r"\bDispatchQueue\b", ignored))
        self.assertIsNone(re.search(r"\bDateFormatter\b", ignored))
        self.assertIsNone(re.search(r"CFArrayGetValueAtIndex", ignored))
        self.assertIsNotNone(
            re.search(r"\bDispatchQueue\b", blank_non_code("DispatchQueue.main.async { }\n"))
        )
        self.assertIsNotNone(
            re.search(
                r"String\(\s*format:",
                blank_non_code('let value = String(\n    format: "%02x", 10)\n'),
            )
        )

    def test_swiftlint_encodes_the_agent_antipatterns(self):
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        for rule in CUSTOM_RULES:
            with self.subTest(rule=rule):
                self.assertIn(f"{rule}:", configuration)

    def test_swiftlint_custom_rules_match_code_not_comments(self):
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        blocks = configuration.split("custom_rules:\n", 1)[1]
        for rule in CUSTOM_RULES:
            with self.subTest(rule=rule):
                rest = blocks.split(f"  {rule}:\n", 1)[1]
                next_rule = rest.find("\n  no_")
                block = rest if next_rule == -1 else rest[:next_rule]
                self.assertIn("match_kinds:", block)
                self.assertNotIn("- comment", block)
                self.assertNotIn("- string", block)
        observation = blocks.split("  no_observable_object:\n", 1)[1]
        observation = observation[:observation.find("\n  no_")]
        self.assertIn("attribute.id", observation)
        picker = blocks.split("  no_swiftui_picker:\n", 1)[1]
        picker = picker[:picker.find("\n  no_")]
        self.assertIn("Configuration|Onboarding|Shared|AppAssignments", picker)
        tab_item = blocks.split("  no_tab_item:\n", 1)[1]
        next_rule = tab_item.find("\n  no_")
        tab_item = tab_item if next_rule == -1 else tab_item[:next_rule]
        self.assertIn("{", tab_item)
        self.assertIn("(", tab_item)
        string_format = blocks.split("  no_string_format:\n", 1)[1]
        string_format = string_format[:string_format.find("\n  no_")]
        self.assertIn("\\s*", string_format)

    def test_safety_audit_still_rejects_cfarray_element_access(self):
        run_script = (ROOT / "Scripts" / "run.sh").read_text(encoding="utf-8")
        self.assertIn("CFArrayGetValueAtIndex", run_script)
        self.assertIn("--exclude='*.py'", run_script)
        self.assertNotIn("--include='*.swift'", run_script)

    def test_ci_runs_these_policy_tests_on_linux(self):
        workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("test_source_policy.py", workflow)
        self.assertRegex(workflow, r"(?m)^  policy:")


if __name__ == "__main__":
    unittest.main()
