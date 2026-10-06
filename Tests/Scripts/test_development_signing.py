import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class DevelopmentSigningTests(unittest.TestCase):
    def test_only_hosted_test_commands_opt_into_ad_hoc_signing(self):
        script = r'''
set -euo pipefail
source <(sed -n '/^run_tests()/,/^}/p' Scripts/run.sh)
source <(sed -n '/^build_app()/,/^}/p' Scripts/run.sh)
DERIVED_DATA_PATH=/tmp/keyameleon-signing-test
python3() { :; }
kill_leftover_derived_data_keyameleon() { :; }
xcodebuild() { printf '%s\t' "$@"; printf '\n'; }
run_tests
build_app
'''
        result = subprocess.run(
            ("zsh", "-c", script), cwd=ROOT, capture_output=True, text=True,
            check=True,
        )
        commands = [line.rstrip("\t").split("\t") for line in result.stdout.splitlines()]
        self.assertEqual([command[0] for command in commands],
                         ["build-for-testing", "test-without-building", "build"])
        for command in commands[:2]:
            self.assertIn("CODE_SIGN_IDENTITY=-", command)
            self.assertIn("CODE_SIGNING_REQUIRED=NO", command)
        self.assertFalse(any(argument.startswith("CODE_SIGN") for argument in commands[2]))

    def test_generate_selects_a_local_certificate_and_clears_stale_selection(self):
        functions = ROOT / "Scripts/run.sh"
        script = r'''
set -euo pipefail
source <(sed -n '/^generate_project()/,/^}/p' "$1")
source <(sed -n '/^development_signing_identity()/,/^}/p' "$1")
xcodegen() { :; }
write_modern_workspace_settings() { :; }
neutralize_legacy_user_build_locations() { :; }
security() { cat identities; }
generate_project
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Config").mkdir()
            fixture = root / "identities"
            fingerprint = "A" * 40
            fixture.write_text(
                '  1) ' + "B" * 40 + ' "Developer ID Application: Fixture"\n'
                '  2) ' + fingerprint + ' "Apple Development: Fixture"\n'
                '  3) ' + "C" * 40 + ' "Apple Development: Second"\n'
            )
            def generate():
                subprocess.run(("zsh", "-c", script, "--", str(functions)),
                               cwd=root, capture_output=True, text=True, check=True)
            generate()
            local = root / "Config/Development.local.xcconfig"
            self.assertTrue(local.exists(), "generation must write the local signing config")
            self.assertEqual(local.read_text(),
                             f"KEYAMELEON_DEVELOPMENT_SIGNING_IDENTITY = {fingerprint}\n")
            fixture.write_text("0 valid identities found\n")
            generate()
            self.assertEqual(local.read_text(), "")

    def test_generated_debug_settings_require_stable_signing_for_every_target(self):
        result = subprocess.run(
            ("plutil", "-convert", "json", "-o", "-", "Keyameleon.xcodeproj/project.pbxproj"),
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        project = json.loads(result.stdout)
        objects = project["objects"]
        root = objects[project["rootObject"]]

        def settings(owner, configuration):
            configs = objects[owner["buildConfigurationList"]]["buildConfigurations"]
            return next(objects[key]["buildSettings"] for key in configs
                        if objects[key]["name"] == configuration)

        configs = objects[root["buildConfigurationList"]]["buildConfigurations"]
        debug = next(objects[key] for key in configs if objects[key]["name"] == "Debug")
        reference = objects[debug["baseConfigurationReference"]]
        self.assertEqual(reference["path"], "Development.xcconfig")
        self.assertEqual((ROOT / "Config/Development.xcconfig").read_text(),
                         'KEYAMELEON_DEVELOPMENT_SIGNING_IDENTITY = Apple Development\n'
                         '#include? "Development.local.xcconfig"\n')

        for target_id in root["targets"]:
            target = objects[target_id]
            for configuration, identity, required in (
                ("Debug", "$(KEYAMELEON_DEVELOPMENT_SIGNING_IDENTITY)", "YES"), ("Release", "-", "NO"),
            ):
                with self.subTest(target=target["name"], configuration=configuration):
                    effective = settings(root, configuration) | settings(target, configuration)
                    self.assertEqual(effective["CODE_SIGN_STYLE"], "Manual")
                    self.assertEqual(effective["CODE_SIGN_IDENTITY"], identity)
                    self.assertEqual(effective["CODE_SIGNING_REQUIRED"], required)


if __name__ == "__main__":
    unittest.main()
