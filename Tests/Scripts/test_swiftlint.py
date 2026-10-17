import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FORM_SOURCE = "Sources/Features/Configuration/Example.swift"


class SwiftLintPolicyTests(unittest.TestCase):
    def test_lint_rejects_warnings_correctness_findings_and_version_drift(self):
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        clean_source = "struct ValidName { let value = 1 }\n"
        cases = (
            (FORM_SOURCE, clean_source, configuration, None),
            (FORM_SOURCE, "// DispatchQueue is deliberately avoided here\n" + clean_source,
             configuration, None),
            (FORM_SOURCE, 'let text = "DispatchQueue"\n' + clean_source, configuration, None),
            (FORM_SOURCE, clean_source + " \n", configuration, "trailing_whitespace"),
            (FORM_SOURCE, 'let value = "text" as! Int\n', configuration, "force_cast"),
            (FORM_SOURCE, "class Example: ObservableObject {}\n", configuration,
             "no_observable_object"),
            (FORM_SOURCE, "@ObservedObject var model: Example\n", configuration,
             "no_observable_object"),
            (FORM_SOURCE, "@StateObject var model = Example()\n", configuration,
             "no_observable_object"),
            (FORM_SOURCE, "@EnvironmentObject var model: Example\n", configuration,
             "no_observable_object"),
            (FORM_SOURCE, "DispatchQueue.main.async { }\n", configuration, "no_gcd"),
            (FORM_SOURCE, 'Picker("Layout", selection: $value) { }\n', configuration,
             "no_swiftui_picker"),
            ("Sources/App/Example.swift", 'Picker("Layout", selection: $value) { }\n',
             configuration, None),
            (FORM_SOURCE, 'let value = String(format: "%02x", 10)\n', configuration,
             "no_string_format"),
            (FORM_SOURCE, 'let value = String(\n    format: "%02x", 10)\n', configuration,
             "no_string_format"),
            (FORM_SOURCE, "_ = CFArrayGetValueAtIndex(array, 0)\n", configuration,
             "no_cfarray_get_value"),
            (FORM_SOURCE, ".tabItem { EmptyView() }\n", configuration, "no_tab_item"),
            (FORM_SOURCE, clean_source, configuration.replace('"0.65.1"', '"0.0.0"'),
             "configuration specified version 0.0.0"),
        )
        script = r'''
source <(sed -n '/^lint_sources()/,/^}/p' "$1")
cd "$2"
lint_sources
'''
        for relative_path, source, config, finding in cases:
            with self.subTest(finding=finding, path=relative_path), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / relative_path
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source, encoding="utf-8")
                (root / ".swiftlint.yml").write_text(config, encoding="utf-8")
                result = subprocess.run(
                    ("zsh", "-c", script, "test", str(ROOT / "Scripts/run.sh"), directory),
                    capture_output=True,
                    text=True,
                    check=False,
                )
                output = result.stdout + result.stderr
                if finding is None:
                    self.assertEqual(result.returncode, 0, output)
                    self.assertEqual(output, "")
                else:
                    self.assertNotEqual(result.returncode, 0, output)
                    self.assertIn(finding, output)


if __name__ == "__main__":
    unittest.main()
