import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class ProjectIdentityTests(unittest.TestCase):
    def test_debug_and_release_build_and_test_the_shipped_app(self):
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

        for configuration in ("Debug", "Release"):
            with self.subTest(configuration=configuration):
                app = settings(root, configuration) | settings(targets["Keyameleon"], configuration)
                self.assertEqual(app["PRODUCT_BUNDLE_IDENTIFIER"], "dev.fedemas.keyameleon")
                self.assertEqual(app["PRODUCT_NAME"], "Keyameleon")
                for name in ("KeyameleonSwiftTesting", "KeyameleonXCTest"):
                    self.assertEqual(settings(targets[name], configuration)["TEST_HOST"],
                                     "$(BUILT_PRODUCTS_DIR)/Keyameleon.app/Contents/MacOS/Keyameleon")


if __name__ == "__main__":
    unittest.main()
