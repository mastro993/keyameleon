#!/usr/bin/env python3
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class BundleLicensesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.script = self.root / "Scripts/bundle-licenses.py"
        self.script.parent.mkdir()
        shutil.copyfile(ROOT / "Scripts/bundle-licenses.py", self.script)
        self.packages = self.root / "SourcePackages"
        artifact = self.packages / "artifacts/sparkle/Sparkle"
        self.app = self.root / "Keyameleon.app"
        self.destination = self.app / "Contents/Resources/Licenses"
        self.frameworks = (
            artifact / "Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework",
            self.app / "Contents/Frameworks/Sparkle.framework",
        )
        for framework in self.frameworks:
            info = framework / "Resources/Info.plist"
            info.parent.mkdir(parents=True)
            info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "2.10.0"}))
        resolved = self.root / "Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        resolved.parent.mkdir(parents=True)
        resolved.write_text(json.dumps({"pins": [{"identity": "sparkle", "state": {"version": "2.10.0"}}]}))
        self.sources = {
            "LICENSE.txt": self.root / "LICENSE",
            "THIRD_PARTY_NOTICES.md": self.root / "THIRD_PARTY_NOTICES.md",
            "Sparkle-LICENSE.txt": artifact / "LICENSE",
        }
        self.texts = {
            "LICENSE.txt": b"GPL license fixture\n",
            "THIRD_PARTY_NOTICES.md": b"Third-party index fixture\n",
            "Sparkle-LICENSE.txt": b"Sparkle MIT fixture\r\nExternal component license fixture\r\n",
        }
        for name, path in self.sources.items():
            path.write_bytes(self.texts[name])

    def run_cli(self, *arguments, build_dir=None):
        location = ["--package-root", str(self.packages)] if build_dir is None else ["--build-dir", str(build_dir)]
        return subprocess.run(
            [sys.executable, str(self.script), "--app", str(self.app),
             *location, *arguments],
            capture_output=True, text=True, check=False,
        )

    def test_copy_finds_packages_above_normal_and_archive_build_directories(self):
        derived_data = self.root / "DerivedData"
        derived_data.mkdir()
        shutil.move(self.packages, derived_data / "SourcePackages")
        for relative in ("Build/Products", "Build/Intermediates.noindex/ArchiveIntermediates/Keyameleon/BuildProductsPath"):
            with self.subTest(build_directory=relative):
                build_dir = derived_data / relative
                build_dir.mkdir(parents=True)
                result = self.run_cli("--copy", build_dir=build_dir)
                self.assertEqual(result.returncode, 0, result.stderr)
                for name, expected in self.texts.items():
                    self.assertEqual((self.destination / name).read_bytes(), expected)
                shutil.rmtree(self.destination)

    def test_copy_fails_when_no_ancestor_has_resolved_packages(self):
        shutil.rmtree(self.packages)
        result = self.run_cli("--copy", build_dir=self.root / "DerivedData/Build/Products")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No resolved Sparkle artifact", result.stderr)
        self.assertFalse(self.destination.exists())

    def test_copy_preserves_complete_bytes_and_verifier_does_not_write(self):
        result = self.run_cli("--copy")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name, expected in self.texts.items():
            self.assertEqual((self.destination / name).read_bytes(), expected)
        timestamps = {name: (self.destination / name).stat().st_mtime_ns for name in self.texts}
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(timestamps, {name: (self.destination / name).stat().st_mtime_ns for name in self.texts})

    def test_verifier_rejects_missing_truncated_and_changed_notices_without_repair(self):
        for name, original in self.texts.items():
            for replacement in (None, original[:5], b"changed notice\n"):
                with self.subTest(name=name, replacement=replacement):
                    self.assertEqual(self.run_cli("--copy").returncode, 0)
                    target = self.destination / name
                    if replacement is None:
                        target.unlink()
                    else:
                        target.write_bytes(replacement)
                    result = self.run_cli()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(name, result.stderr)
                    self.assertEqual(target.read_bytes() if target.exists() else None, replacement)

    def test_copy_rejects_missing_or_empty_sources(self):
        for name, source in self.sources.items():
            for replacement in (None, b"", b" \n"):
                with self.subTest(name=name, replacement=replacement):
                    if replacement is None:
                        source.unlink()
                    else:
                        source.write_bytes(replacement)
                    result = self.run_cli("--copy")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(str(source), result.stderr)
                    self.assertFalse(self.destination.exists())
                    source.write_bytes(self.texts[name])

    def test_copy_runs_before_framework_embedding_but_verification_requires_it(self):
        shutil.rmtree(self.frameworks[1])
        result = self.run_cli("--copy")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(str(self.frameworks[1]), result.stderr)

    def test_rejects_wrong_or_missing_artifact_and_embedded_versions(self):
        for index, framework in enumerate(self.frameworks):
            info = framework / "Resources/Info.plist"
            original = info.read_bytes()
            for version in ("2.9.0", None):
                with self.subTest(framework=framework, version=version):
                    if version is None:
                        info.unlink()
                    else:
                        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": version}))
                    result = self.run_cli("--copy") if index == 0 else self.run_cli()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(str(framework), result.stderr)
                    self.assertFalse(self.destination.exists())
                    info.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
