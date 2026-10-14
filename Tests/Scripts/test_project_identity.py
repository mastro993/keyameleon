import json
import plistlib
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
# Debug has its own bundle ID, so macOS keeps a separate Input Monitoring row and
# defaults domain for it (docs/adr/0008-separate-debug-identity.md).
IDENTITIES = {
    "Debug": ("dev.fedemas.keyameleon.debug", "Keyameleon Dev"),
    "Release": ("dev.fedemas.keyameleon", "Keyameleon"),
}


class ProjectIdentityTests(unittest.TestCase):
    def test_debug_and_release_have_separate_identities_and_one_module(self):
        result = subprocess.run(
            ("plutil", "-convert", "json", "-o", "-", "Keyameleon.xcodeproj/project.pbxproj"),
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        project = json.loads(result.stdout)
        objects = project["objects"]
        root = objects[project["rootObject"]]
        targets = {objects[key]["name"]: objects[key] for key in root["targets"]}

        def settings(owner, configuration):
            configs = objects[owner["buildConfigurationList"]]["buildConfigurations"]
            return next(objects[key]["buildSettings"] for key in configs
                        if objects[key]["name"] == configuration)

        for configuration, (bundle_id, product_name) in IDENTITIES.items():
            with self.subTest(configuration=configuration):
                app = settings(root, configuration) | settings(targets["Keyameleon"], configuration)
                self.assertEqual(app["PRODUCT_BUNDLE_IDENTIFIER"], bundle_id)
                # The bundle file names the app in System Settings and Finder.
                self.assertEqual(app["PRODUCT_NAME"], product_name)
                self.assertEqual(app["INFOPLIST_KEY_CFBundleDisplayName"], "$(PRODUCT_NAME)")
                # The module and executable stay Keyameleon in both.
                self.assertEqual(app["PRODUCT_MODULE_NAME"], "Keyameleon")
                self.assertEqual(app["EXECUTABLE_NAME"], "Keyameleon")
                for name in ("KeyameleonSwiftTesting", "KeyameleonXCTest"):
                    self.assertEqual(
                        settings(targets[name], configuration)["TEST_HOST"],
                        f"$(BUILT_PRODUCTS_DIR)/{product_name}.app/Contents/MacOS/Keyameleon",
                    )

        info = plistlib.loads((ROOT / "Sources/App/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleIdentifier"], "$(PRODUCT_BUNDLE_IDENTIFIER)")
        self.assertEqual(info["CFBundleDisplayName"], "$(PRODUCT_NAME)")
        self.assertEqual(info["CFBundleName"], "$(PRODUCT_NAME)")

    def test_run_script_targets_the_project_identities(self):
        result = subprocess.run(
            ("zsh", "-c", "source <(sed -n -e '/^BUNDLE_ID=/p' -e '/^RELEASE_BUNDLE_ID=/p' Scripts/run.sh); "
                          "print -r -- \"$BUNDLE_ID $RELEASE_BUNDLE_ID\""),
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stdout.split(), [IDENTITIES["Debug"][0], IDENTITIES["Release"][0]])

    def test_run_script_uses_the_debug_product_name(self):
        result = subprocess.run(
            ("zsh", "-c", "source <(sed -n '/^DEBUG_APP_NAME=/p' Scripts/run.sh); print -r -- \"$DEBUG_APP_NAME\""),
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), IDENTITIES["Debug"][1])


if __name__ == "__main__":
    unittest.main()
