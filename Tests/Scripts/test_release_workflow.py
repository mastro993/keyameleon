#!/usr/bin/env python3
import fnmatch
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, WORKFLOW, workflow_step


def script_text(name: str) -> str:
    return (ROOT / "Scripts" / name).read_text(encoding="utf-8")


class ReleaseWorkflowTests(unittest.TestCase):
    def test_producer_cannot_write_repository_or_change_publisher_source(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("\n  produce:\n", workflow)
        producer = workflow.split("\n  produce:\n", 1)[1].split("\n  publish:\n", 1)[0]
        publisher = workflow.split("\n  publish:\n", 1)[1]
        publisher += "".join(script_text(name) for name in re.findall(r"bash Scripts/([\w.-]+)", publisher))
        self.assertNotIn("RELEASE_DEPLOY_KEY", producer)
        self.assertNotIn("contents: write", producer)
        self.assertIn("persist-credentials: false", producer)
        self.assertIn("ref: ${{ github.sha }}", publisher)
        self.assertNotIn("git checkout", publisher)
        self.assertNotIn("./Scripts/run.sh test", publisher)
        self.assertNotIn("./Scripts/official-release.sh", publisher)
        self.assertNotIn("secrets.APPLE_", publisher)
        self.assertIn('git tag -a "$TAG" "$COMMIT"', publisher)

    def test_run_tests_rejects_invalid_pages_publisher(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            scripts = Path(temporary_directory) / "Scripts"
            scripts.mkdir()
            for name in ("official-release-notes.sh", "verify-official-release-tag.sh",
                         "write-release-evidence.sh", "official-release.sh"):
                (scripts / name).write_text("exit 0\n", encoding="utf-8")
            (scripts / "publish-release-pages.sh").write_text("if\n", encoding="utf-8")
            command = r'''
set -e
source <(sed -n '/^run_tests()/,/^}/p' "$1")
cd "$2"
python3() { return 0; }
xcodebuild() { return 0; }
kill_leftover_derived_data_keyameleon() { return 0; }
DERIVED_DATA_PATH="$2/build"
run_tests
'''
            result = subprocess.run(
                ("zsh", "-c", command, "test", str(ROOT / "Scripts/run.sh"), temporary_directory),
                capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Scripts/publish-release-pages.sh", result.stderr)
            self.assertIn("syntax error", result.stderr)

    def test_version_commit_installs_pinned_swiftlint_before_tests(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release = workflow.split("\n  produce:\n", maxsplit=1)[1].split("\n  publish:\n", 1)[0]
        before_tests = release.split("- name: Test version commit", maxsplit=1)[0]
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        version = configuration.split('swiftlint_version: "', maxsplit=1)[1].split('"', maxsplit=1)[0]
        ci_workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        checksum_command = next(
            line.strip() for line in ci_workflow.splitlines()
            if line.strip().startswith('echo "') and "swiftlint.zip" in line
        )
        self.assertIn(f"Install SwiftLint {version}", before_tests)
        self.assertIn(f"/releases/download/{version}/portable_swiftlint.zip", before_tests)
        self.assertIn(checksum_command, before_tests)
        self.assertIn("| shasum -a 256 --check", before_tests)
        self.assertIn('echo "${swiftlint_dir}" >> "${GITHUB_PATH}"', before_tests)

    def test_dispatch_selects_release_type_and_tags_the_bump_commit(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("release_type:", workflow)
        self.assertIn("type: choice", workflow)
        self.assertIn("default: patch", workflow)
        self.assertIn("- major\n          - minor\n          - patch", workflow)
        self.assertNotIn("inputs.version", workflow)
        self.assertIn("run: bash Scripts/prepare-release-bump.sh", workflow_step("Prepare version commit"))
        self.assertIn('git commit -m "chore(release): ${VERSION}"', script_text("prepare-release-bump.sh"))
        self.assertIn("COMMIT: ${{ steps.bump.outputs.commit }}", workflow)
        notes = workflow_step("Prepare Official Release tag and notes")
        self.assertIn("SOURCE_SHA: ${{ github.sha }}", notes)
        self.assertIn("run: bash Scripts/tag-official-release.sh", notes)
        self.assertIn('--head "${SOURCE_SHA}"', script_text("tag-official-release.sh"))

    def test_batch_approval_preserves_isolated_publication_order(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertEqual(workflow.count("environment: official-release"), 3)
        for job in ("bump", "produce", "publish"):
            body = workflow.split(f"\n  {job}:\n", 1)[1].split("\n  bump:\n", 1)[0].split("\n  produce:\n", 1)[0].split("\n  publish:\n", 1)[0]
            self.assertIn("needs: verify", body)
        producer = workflow.split("\n  produce:\n", 1)[1].split("\n  publish:\n", 1)[0]
        publisher = workflow.split("\n  publish:\n", 1)[1]
        self.assertLess(producer.index("Test version commit"), producer.index("Upload workflow artifacts"))
        for step in ("Test version commit", "Produce signed, notarized, stapled artifacts", "Upload workflow artifacts"):
            self.assertIn(f"- name: {step}\n        if: steps.saved.outputs.restored != 'true'", producer)
        steps = ("Wait for saved release artifacts", "Validate published version commit",
                 "Require complete artifact bundle", "Prepare Official Release tag and notes",
                 "Publish and verify downloadable DMG", "bash Scripts/publish-release-pages.sh",
                 "Verify published feed and enclosure")
        self.assertEqual([publisher.index(step) for step in steps], sorted(publisher.index(step) for step in steps))
        self.assertIn("run: bash Scripts/verify-published-release.sh", workflow_step("Verify published feed and enclosure"))
        self.assertIn('cmp -s "$RUNNER_TEMP/published-evidence.json" dist/release-evidence.json',
                      script_text("verify-published-release.sh"))
        self.assertNotIn("Keyameleon-source-", workflow)

    def test_protected_version_commit_and_tag_use_deploy_key(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release = workflow.split("\n  publish:\n", maxsplit=1)[1]
        checkout = release.split("- uses: actions/checkout@v7\n", maxsplit=1)[1].split("\n\n", maxsplit=1)[0]
        self.assertIn("ssh-key: ${{ secrets.RELEASE_DEPLOY_KEY }}", checkout)
        self.assertIn("environment: official-release", release)

        documentation = (ROOT / "docs" / "release" / "one-time-setup.md").read_text(
            encoding="utf-8"
        )
        glob = documentation.split("Target tags: `", maxsplit=1)[1].split("`", maxsplit=1)[0]
        self.assertTrue(fnmatch.fnmatchcase("v0.4.5", glob))
        self.assertTrue(fnmatch.fnmatchcase("v0notasemver", glob))
        rejected = subprocess.run(
            (str(ROOT / "Scripts" / "verify-official-release-tag.sh"), "v0notasemver"),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(rejected.returncode, 1)


if __name__ == "__main__":
    unittest.main()
