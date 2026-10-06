import json
import subprocess
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

        for target_id in root["targets"]:
            target = objects[target_id]
            for configuration, identity, required in (
                ("Debug", "Apple Development", "YES"), ("Release", "-", "NO"),
            ):
                with self.subTest(target=target["name"], configuration=configuration):
                    effective = settings(root, configuration) | settings(target, configuration)
                    self.assertEqual(effective["CODE_SIGN_STYLE"], "Manual")
                    self.assertEqual(effective["CODE_SIGN_IDENTITY"], identity)
                    self.assertEqual(effective["CODE_SIGNING_REQUIRED"], required)


if __name__ == "__main__":
    unittest.main()
