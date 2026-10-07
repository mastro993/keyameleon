#!/usr/bin/env python3
import base64
import fnmatch
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from collections.abc import Callable
from itertools import takewhile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "release.yml"
EVIDENCE_SCRIPT = ROOT / "Scripts" / "write-release-evidence.sh"
VERSION_FILES = ["Keyameleon.xcodeproj/project.pbxproj", "project.yml"]
SCHEME = "Keyameleon.xcodeproj/xcshareddata/xcschemes/Keyameleon.xcscheme"
VERSION_SETTING = re.compile(r'^    MARKETING_VERSION: "([^"]+)"$', re.MULTILINE)
BOT = "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>"
GIT_ENV = os.environ | {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "Release Tester",
    "GIT_AUTHOR_EMAIL": "release@example.com",
    "GIT_COMMITTER_NAME": "Release Tester",
    "GIT_COMMITTER_EMAIL": "release@example.com",
}
FAKE_XCODEGEN = """#!/usr/bin/env python3
import pathlib
import re

version = re.search(r'^    MARKETING_VERSION: "([^"]+)"$', pathlib.Path("project.yml").read_text(), re.M)[1]
project = pathlib.Path("Keyameleon.xcodeproj/project.pbxproj")
project.write_text(re.sub(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", project.read_text()))
pathlib.Path("Keyameleon.xcodeproj/xcshareddata/xcschemes/Keyameleon.xcscheme").write_text("generated scheme\\n")
"""


def workflow_jobs() -> dict[str, str]:
    jobs = WORKFLOW.read_text(encoding="utf-8").split("\njobs:\n", 1)[1]
    parts = re.split(r"(?m)^  ([\w-]+):\n", jobs)
    return dict(zip(parts[1::2], parts[2::2]))


def job_steps(job: str) -> dict[str, str]:
    steps = re.split(r"(?m)^      - ", job.split("\n    steps:\n", 1)[1])[1:]
    return {step.split("\n", 1)[0].removeprefix("name: "): step for step in steps}


def step_script(step: str) -> str:
    body = step.split("run: |\n", 1)[1].splitlines(keepends=True)
    return textwrap.dedent("".join(takewhile(lambda line: not line.strip() or line.startswith(" " * 10), body)))


def run_step(name: str, cwd: Path, **environment: str) -> subprocess.CompletedProcess[str]:
    script = step_script(job_steps(workflow_jobs()["release"])[name])
    return subprocess.run(("bash", "-c", script), cwd=cwd, env=GIT_ENV | environment, text=True, capture_output=True)


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ("git", *args), cwd=cwd, env=GIT_ENV, check=True, text=True, capture_output=True
    ).stdout.strip()


def publish_source(source: Path, tag: str) -> tuple[Path, str]:
    git(source, "init", "-q", "-b", "main")
    git(source, "add", "--all", "--force")
    git(source, "commit", "-q", "-m", "Release source")
    git(source, "tag", tag)
    origin = source.with_suffix(".git")
    git(source.parent, "init", "-q", "--bare", str(origin))
    git(source, "push", "-q", str(origin), "main", "--tags")
    return origin, git(source, "rev-parse", "HEAD")


def checkout(origin: Path, commit: str, destination: Path) -> Path:
    git(origin.parent, "clone", "-q", str(origin), str(destination))
    git(destination, "checkout", "-q", "--detach", commit)
    return destination


def prepare_version_commit(
    origin: Path, source: str, runner: Path, version: str, path: str = os.environ["PATH"]
) -> tuple[subprocess.CompletedProcess[str], Path]:
    checkout(origin, source, runner)
    output = runner.with_suffix(".output")
    result = run_step(
        "Prepare version commit", runner, PATH=path, DEFAULT_BRANCH="main", RELEASE_TYPE="patch",
        SOURCE_SHA=source, VERSION=version, GITHUB_OUTPUT=str(output),
    )
    return result, output


class ReleaseWorkflowTests(unittest.TestCase):
    def test_verify_job_checks_dispatch_without_waiting_for_ci(self) -> None:
        verify = workflow_jobs()["verify"]
        self.assertNotIn("environment:", verify)
        self.assertIn("    permissions:\n      contents: read\n    outputs:", verify)
        self.assertEqual(
            list(job_steps(verify)),
            ["uses: actions/checkout@v7", "Require default branch", "Calculate next Official Release version"],
        )
        self.assertNotIn("wait-for-ci", WORKFLOW.read_text(encoding="utf-8"))
        self.assertFalse((ROOT / "Scripts" / "wait-for-ci.sh").exists())

    def test_one_protected_job_needs_verify_and_runs_stages_in_order(self) -> None:
        jobs = workflow_jobs()
        self.assertEqual([name for name, job in jobs.items() if "environment:" in job], ["release"])
        release = jobs["release"]
        header = release.split("\n    steps:\n", 1)[0]
        self.assertIn("\n    needs: verify\n", header)
        self.assertIn("\n    environment: official-release\n", header)
        self.assertNotIn("\n    if:", header)
        self.assertIsNone(re.search(r"\b(always|failure|cancelled)\(\)", release))
        names = list(job_steps(release))
        stages = (
            "Prepare version commit",
            "Test version commit",
            "Produce signed, notarized, stapled artifacts",
            "Require complete artifact bundle",
            "Upload workflow artifacts",
            "Check out publisher with release deploy key",
            "Push version commit and tag",
            "Publish and verify downloadable DMG",
            "Publish Sparkle appcast and permanent evidence to GitHub Pages",
            "Verify published feed and enclosure",
        )
        self.assertEqual([names.index(stage) for stage in stages], sorted(names.index(stage) for stage in stages))

    def test_jobs_do_not_poll_for_other_jobs(self) -> None:
        for job_name, job in workflow_jobs().items():
            for name, step in job_steps(job).items():
                if name == "Verify published feed and enclosure":
                    continue
                with self.subTest(job=job_name, step=name):
                    self.assertNotIn("sleep", step)
                    self.assertNotIn("for attempt", step)

    def test_saved_artifacts_skip_tests_and_signing_but_not_validation(self) -> None:
        steps = job_steps(workflow_jobs()["release"])
        skipped = "        if: steps.saved.outputs.restored != 'true'\n"
        for name in ("Install SwiftLint 0.65.1", "Test version commit", "Produce signed, notarized, stapled artifacts",
                     "Upload workflow artifacts"):
            self.assertIn(skipped, steps[name], name)
        for name in ("Prepare version commit", "Require complete artifact bundle", "Push version commit and tag"):
            self.assertNotIn(skipped, steps[name], name)

    def test_deploy_key_and_signing_secrets_stay_in_their_stages(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        steps = job_steps(workflow_jobs()["release"])
        names = list(steps)
        self.assertIn("persist-credentials: false", steps["uses: actions/checkout@v7"])
        self.assertEqual([name for name, step in steps.items() if "secrets.RELEASE_DEPLOY_KEY" in step],
                         ["Check out publisher with release deploy key"])
        self.assertEqual(workflow.count("secrets.RELEASE_DEPLOY_KEY"), 1)
        signing = [name for name, step in steps.items() if re.search(r"secrets\.(APPLE|SPARKLE)_", step)]
        self.assertEqual(signing, ["Produce signed, notarized, stapled artifacts"])
        self.assertEqual(len(re.findall(r"secrets\.(APPLE|SPARKLE)_", workflow)), 8)
        publisher = names.index("Check out publisher with release deploy key")
        self.assertIn("ref: ${{ github.sha }}", steps[names[publisher]])
        self.assertIn("path: publisher", steps[names[publisher]])
        for name in names[publisher + 1:]:
            with self.subTest(step=name):
                self.assertIn("        working-directory: publisher\n", steps[name])
                self.assertNotIn("Scripts/run.sh", steps[name])
                self.assertNotIn("official-release.sh", steps[name])

    def test_version_commit_installs_pinned_swiftlint_before_tests(self) -> None:
        steps = job_steps(workflow_jobs()["release"])
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        version = configuration.split('swiftlint_version: "', maxsplit=1)[1].split('"', maxsplit=1)[0]
        ci_workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        checksum_command = next(
            line.strip() for line in ci_workflow.splitlines()
            if line.strip().startswith('echo "') and "swiftlint.zip" in line
        )
        names = list(steps)
        self.assertLess(names.index(f"Install SwiftLint {version}"), names.index("Test version commit"))
        install = steps[f"Install SwiftLint {version}"]
        self.assertIn(f"/releases/download/{version}/portable_swiftlint.zip", install)
        self.assertIn(checksum_command, install)
        self.assertIn("| shasum -a 256 --check", install)
        self.assertIn('echo "${swiftlint_dir}" >> "${GITHUB_PATH}"', install)
        self.assertIn("./Scripts/run.sh test\n          git diff --exit-code", steps["Test version commit"])

    def test_dispatch_selects_release_type_and_tag_documentation_matches_ruleset(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("type: choice", workflow)
        self.assertIn("default: patch", workflow)
        self.assertIn("- major\n          - minor\n          - patch", workflow)
        self.assertNotIn("inputs.version", workflow)
        documentation = (ROOT / "docs" / "release" / "official-release.md").read_text(encoding="utf-8")
        glob = documentation.split("Target tags: `", maxsplit=1)[1].split("`", maxsplit=1)[0]
        self.assertTrue(fnmatch.fnmatchcase("v0.4.5", glob))
        self.assertTrue(fnmatch.fnmatchcase("v0notasemver", glob))
        rejected = subprocess.run(
            (str(ROOT / "Scripts" / "verify-official-release-tag.sh"), "v0notasemver"),
            cwd=ROOT, check=False, text=True, capture_output=True,
        )
        self.assertEqual(rejected.returncode, 1)


class ReleaseVersionCommitTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        fake_bin = self.directory / "bin"
        fake_bin.mkdir()
        (fake_bin / "xcodegen").write_text(FAKE_XCODEGEN, encoding="utf-8")
        (fake_bin / "xcodegen").chmod(0o755)
        self.path = f"{fake_bin}{os.pathsep}{os.environ['PATH']}"
        self.runs = 0

    def origin(self, name: str, scheme: str = "generated scheme\n") -> tuple[Path, str]:
        source = self.directory / name
        files = {
            "project.yml": 'settings:\n  base:\n    MARKETING_VERSION: "1.2.2"\n',
            "Keyameleon.xcodeproj/project.pbxproj": "MARKETING_VERSION = 1.2.2;\nMARKETING_VERSION = 1.2.2;\n",
            SCHEME: scheme,
            "README.md": "source\n",
        }
        for path, content in files.items():
            (source / path).parent.mkdir(parents=True, exist_ok=True)
            (source / path).write_text(content, encoding="utf-8")
        (source / "Scripts").mkdir()
        for script in ("release-version.py", "verify-official-release-tag.sh"):
            shutil.copy2(ROOT / "Scripts" / script, source / "Scripts" / script)
        return publish_source(source, "v1.2.2")

    def prepare(self, origin: Path, source: str, version: str = "1.2.3") -> tuple[subprocess.CompletedProcess[str], Path, Path]:
        self.runs += 1
        runner = self.directory / f"runner-{self.runs}"
        result, output = prepare_version_commit(origin, source, runner, version, self.path)
        return result, runner, output

    def advance(self, origin: Path, source: str, subject: str, files: dict[str, str]) -> None:
        self.runs += 1
        editor = checkout(origin, source, self.directory / f"editor-{self.runs}")
        for path, content in files.items():
            (editor / path).write_text(content, encoding="utf-8")
        git(editor, "commit", "-qam", subject)
        git(editor, "push", "-q", "origin", "HEAD:refs/heads/main")

    def test_new_version_commit_changes_only_version_files_and_retry_recreates_it(self) -> None:
        origin, source = self.origin("source")
        first, runner, output = self.prepare(origin, source)
        self.assertEqual(first.returncode, 0, first.stderr)
        commit = git(runner, "rev-parse", "HEAD")
        self.assertEqual(output.read_text(encoding="utf-8"), f"commit={commit}\npushed=false\n")
        self.assertEqual(git(runner, "log", "-1", "--format=%P%n%s", commit), f"{source}\nchore(release): 1.2.3")
        self.assertEqual(git(runner, "diff-tree", "--no-commit-id", "--name-only", "-r", commit).splitlines(), VERSION_FILES)
        self.assertEqual(VERSION_SETTING.search(git(runner, "show", f"{commit}:project.yml"))[1], "1.2.3")
        source_date = git(runner, "log", "-1", "--format=%cI", source)
        self.assertEqual(git(runner, "log", "-1", "--format=%an <%ae>%n%cn <%ce>", commit), f"{BOT}\n{BOT}")
        self.assertEqual(git(runner, "log", "-1", "--format=%aI %cI", commit), f"{source_date} {source_date}")

        retried, _, retried_output = self.prepare(origin, source)
        self.assertEqual(retried.returncode, 0, retried.stderr)
        self.assertEqual(retried_output.read_text(encoding="utf-8"), f"commit={commit}\npushed=false\n")
        self.assertEqual(git(origin, "rev-parse", "main"), source)

    def test_retry_after_publication_push_reuses_main(self) -> None:
        origin, source = self.origin("source")
        first, runner, _ = self.prepare(origin, source)
        self.assertEqual(first.returncode, 0, first.stderr)
        commit = git(runner, "rev-parse", "HEAD")
        git(runner, "push", "-q", "origin", f"{commit}:refs/heads/main")

        retried, retried_runner, output = self.prepare(origin, source)
        self.assertEqual(retried.returncode, 0, retried.stderr)
        self.assertEqual(output.read_text(encoding="utf-8"), f"commit={commit}\npushed=true\n")
        self.assertEqual(git(retried_runner, "rev-parse", "HEAD"), commit)

    def test_unexpected_main_generated_files_or_version_stop_before_commit(self) -> None:
        bumped = {
            "project.yml": 'settings:\n  base:\n    MARKETING_VERSION: "1.2.3"\n',
            "Keyameleon.xcodeproj/project.pbxproj": "MARKETING_VERSION = 1.2.3;\nMARKETING_VERSION = 1.2.3;\n",
        }
        main_changed = "main changed before the release bump; dispatch again from current main\n"
        cases = (
            ("advanced", "fix: unrelated change", {"README.md": "changed\n"}, "1.2.3", main_changed),
            ("extra-file", "chore(release): 1.2.3", bumped | {"README.md": "changed\n"}, "1.2.3", main_changed),
            ("other-version", "chore(release): 1.2.3", {
                "project.yml": 'settings:\n  base:\n    MARKETING_VERSION: "1.2.4"\n',
                "Keyameleon.xcodeproj/project.pbxproj": "MARKETING_VERSION = 1.2.4;\nMARKETING_VERSION = 1.2.4;\n",
            }, "1.2.3", main_changed),
            ("hand-edited-scheme", None, {}, "1.2.3",
             f"unexpected release-bump files:\n{VERSION_FILES[0]}\n{SCHEME}\n{VERSION_FILES[1]}\n"),
            ("changed-version", None, {}, "1.3.0", "release version changed: expected 1.3.0, got 1.2.3\n"),
        )
        for name, subject, files, version, error in cases:
            with self.subTest(case=name):
                scheme = "hand-edited scheme\n" if name == "hand-edited-scheme" else "generated scheme\n"
                origin, source = self.origin(name, scheme)
                if subject is not None:
                    self.advance(origin, source, subject, files)
                main = git(origin, "rev-parse", "main")
                result, runner, output = self.prepare(origin, source, version)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stderr[-len(error):], error, result.stderr)
                self.assertFalse(output.exists())
                self.assertEqual(git(runner, "rev-parse", "HEAD"), source)
                self.assertEqual(git(origin, "rev-parse", "main"), main)


@unittest.skipUnless(shutil.which("xcodegen"), "XcodeGen generates the release bump")
class RepositoryReleaseBumpTests(unittest.TestCase):
    def test_release_bump_of_this_project_changes_only_version_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            source = Path(temporary_directory) / "source"
            indexed = subprocess.run(("git", "ls-files", "-z", "--", ":(exclude)design"), cwd=ROOT, check=True,
                                     capture_output=True).stdout
            subprocess.run(("git", "checkout-index", "-z", "--stdin", f"--prefix={source}/"), cwd=ROOT,
                           input=indexed, check=True)
            current = VERSION_SETTING.search((source / "project.yml").read_text(encoding="utf-8"))[1]
            major, minor, patch = (int(component) for component in current.split("."))
            version = f"{major}.{minor}.{patch + 1}"
            origin, source_sha = publish_source(source, f"v{current}")

            result, _ = prepare_version_commit(origin, source_sha, Path(temporary_directory) / "runner", version)
            self.assertEqual(result.returncode, 0, result.stderr)
            runner = Path(temporary_directory) / "runner"
            commit = git(runner, "rev-parse", "HEAD")
            self.assertEqual(git(runner, "diff-tree", "--no-commit-id", "--name-only", "-r", commit).splitlines(), VERSION_FILES)


class SavedArtifactRestoreTests(unittest.TestCase):
    def test_same_run_artifact_recovery_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            fake_bin = directory / "bin"
            fake_bin.mkdir()
            gh = fake_bin / "gh"
            gh.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "run download" ]]; then
  test "$3" = "42"
  test "$4 $5 $6 $7" = "--name official-release-1.2.3 --dir dist"
  test "$CASE" != "download_error"
  mkdir dist
  cp "$SAVED_DMG" dist/Keyameleon-1.2.3.dmg
elif [[ "$*" == *"/artifacts"* ]]; then
  test "$CASE" != "api_error"
  case "$CASE" in
    present|download_error) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false}]}]' ;;
    expired) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":true}]}]' ;;
    duplicate) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false},{"name":"official-release-1.2.3","id":8,"expired":false}]}]' ;;
    *) payload='[{"artifacts":[]}]' ;;
  esac
  printf '%s' "$payload"
else
  test "$CASE" != "release_error"
  if [[ "$CASE" == "release" ]]; then printf '99'; fi
fi
''', encoding="utf-8")
            fake_git = fake_bin / "git"
            fake_git.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
test "$CASE" != "tag_error"
if [[ "$CASE" == "tag" ]]; then printf 'sha\trefs/tags/v1.2.3\n'; fi
''', encoding="utf-8")
            gh.chmod(0o755)
            fake_git.chmod(0o755)
            saved_dmg = directory / "saved.dmg"
            saved_dmg.write_bytes(b"original signed bytes")
            for case in ("absent", "present", "expired", "duplicate", "api_error", "download_error", "tag",
                         "tag_error", "release", "release_error"):
                with self.subTest(case=case):
                    working = directory / case
                    working.mkdir()
                    output = working / "output"
                    result = run_step(
                        "Restore saved release artifacts on retry", working,
                        PATH=f"{fake_bin}:{os.environ['PATH']}", CASE=case, GITHUB_REPOSITORY="example/Keyameleon",
                        GITHUB_RUN_ID="42", GITHUB_OUTPUT=str(output), VERSION="1.2.3", TAG="v1.2.3",
                        SAVED_DMG=str(saved_dmg),
                    )
                    self.assertEqual(result.returncode == 0, case in ("absent", "present"), result.stderr)
                    if case == "present":
                        self.assertEqual(output.read_text(), "restored=true\n")
                        self.assertEqual((working / "dist/Keyameleon-1.2.3.dmg").read_bytes(), saved_dmg.read_bytes())
                    elif case == "absent":
                        self.assertEqual(output.read_text(), "restored=false\n")
                    else:
                        self.assertFalse(output.exists())


class SavedArtifactBundleTests(unittest.TestCase):
    def test_bundle_must_name_the_version_commit_and_tag(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            (directory / "Scripts").symlink_to(ROOT / "Scripts")
            dist = directory / "dist"
            dist.mkdir()
            artifact = dist / "Keyameleon-1.2.3.dmg"
            artifact.write_bytes(b"signed disk image fixture")
            commit = "c" * 40
            subprocess.run(
                (str(EVIDENCE_SCRIPT), "--tag", "v1.2.3", "--commit", commit, "--artifact", str(artifact),
                 "--output", str(dist / "release-evidence.json")),
                check=True, capture_output=True,
            )
            signature = base64.b64encode(bytes(range(64))).decode("ascii")
            (dist / "appcast.xml").write_text(
                '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
                '<channel><item><sparkle:version>1.2.3</sparkle:version>'
                f'<enclosure url="https://github.com/mastro993/Keyameleon/releases/download/v1.2.3/{artifact.name}" '
                f'length="{artifact.stat().st_size}" sparkle:edSignature="{signature}"/>'
                '</item></channel></rss>', encoding="utf-8",
            )
            for name, version_commit, tag, accepted in (
                ("saved", commit, "v1.2.3", True),
                ("recreated-other-commit", "d" * 40, "v1.2.3", False),
                ("other-tag", commit, "v1.2.4", False),
            ):
                with self.subTest(case=name):
                    result = run_step("Require complete artifact bundle", directory,
                                      VERSION="1.2.3", TAG=tag, COMMIT=version_commit)
                    self.assertEqual(result.returncode == 0, accepted, result.stderr)


class PublishVersionCommitTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        source = self.directory / "source"
        source.mkdir()
        (source / "project.yml").write_text("1.2.2\n", encoding="utf-8")
        self.origin, self.source = publish_source(source, "v1.2.2")
        self.workspace = checkout(self.origin, self.source, self.directory / "workspace")
        (self.workspace / "project.yml").write_text("1.2.3\n", encoding="utf-8")
        git(self.workspace, "commit", "-qam", "chore(release): 1.2.3")
        self.commit = git(self.workspace, "rev-parse", "HEAD")
        self.runs = 0

    def publish(
        self,
        commit: str | None = None,
        pushed: str = "false",
        before: Callable[[Path], None] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        self.runs += 1
        publisher = checkout(self.origin, self.source, self.directory / f"publisher-{self.runs}")
        if before is not None:
            before(publisher)
        return run_step(
            "Push version commit and tag", publisher, COMMIT=commit or self.commit, DEFAULT_BRANCH="main",
            GITHUB_WORKSPACE=str(self.workspace), PUSHED=pushed, TAG="v1.2.3", VERSION="1.2.3",
        )

    def remote_refs(self) -> str:
        return git(self.origin, "for-each-ref", "--format=%(refname) %(objecttype) %(objectname)")

    def remote_main(self) -> str:
        return git(self.origin, "rev-parse", "main")

    def remote_tags(self) -> str:
        return git(self.origin, "for-each-ref", "--format=%(refname)", "refs/tags")

    def advance_main(self) -> str:
        self.runs += 1
        editor = checkout(self.origin, self.commit, self.directory / f"editor-{self.runs}")
        (editor / "project.yml").write_text("unrelated\n", encoding="utf-8")
        git(editor, "commit", "-qam", "fix: unrelated change")
        git(editor, "push", "-q", "origin", "HEAD:refs/heads/main")
        return git(editor, "rev-parse", "HEAD")

    def test_push_publishes_commit_then_annotated_tag_and_retry_reuses_them(self) -> None:
        published = self.publish()
        self.assertEqual(published.returncode, 0, published.stderr)
        self.assertEqual(git(self.origin, "rev-parse", "main"), self.commit)
        self.assertEqual(git(self.origin, "cat-file", "-t", "refs/tags/v1.2.3"), "tag")
        self.assertEqual(git(self.origin, "rev-parse", "v1.2.3^{commit}"), self.commit)
        refs = self.remote_refs()

        retried = self.publish(pushed="true")
        self.assertEqual(retried.returncode, 0, retried.stderr)
        self.assertEqual(self.remote_refs(), refs)

    def test_retry_after_main_push_adds_the_missing_tag(self) -> None:
        git(self.workspace, "push", "-q", "origin", f"{self.commit}:refs/heads/main")
        retried = self.publish(pushed="true")
        self.assertEqual(retried.returncode, 0, retried.stderr)
        self.assertEqual(git(self.origin, "rev-parse", "v1.2.3^{commit}"), self.commit)

    def test_wrong_tag_or_commit_publishes_nothing(self) -> None:
        git(self.workspace, "tag", "-a", "v1.2.3", self.source, "-m", "wrong commit")
        git(self.workspace, "push", "-q", "origin", "v1.2.3")
        refs = self.remote_refs()
        wrong_tag = self.publish()
        self.assertNotEqual(wrong_tag.returncode, 0)
        self.assertIn("existing tag v1.2.3 does not point to the release commit", wrong_tag.stderr)
        self.assertEqual(self.remote_refs(), refs)

        git(self.workspace, "push", "-q", "origin", ":refs/tags/v1.2.3")
        refs = self.remote_refs()
        wrong_commit = self.publish(commit=self.source)
        self.assertNotEqual(wrong_commit.returncode, 0)
        self.assertIn(f"workspace HEAD is not version commit {self.source}", wrong_commit.stderr)
        self.assertEqual(self.remote_refs(), refs)

    def test_advanced_main_rejects_push_without_tagging(self) -> None:
        editor = checkout(self.origin, self.source, self.directory / "editor")
        (editor / "project.yml").write_text("unrelated\n", encoding="utf-8")
        git(editor, "commit", "-qam", "fix: unrelated change")
        git(editor, "push", "-q", "origin", "HEAD:refs/heads/main")
        refs = self.remote_refs()

        rejected = self.publish()
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(self.remote_refs(), refs)

    def test_retry_rejects_tag_when_main_advanced_past_the_version_commit(self) -> None:
        git(self.workspace, "push", "-q", "origin", f"{self.commit}:refs/heads/main")
        advanced = self.advance_main()
        refs = self.remote_refs()

        rejected = self.publish(pushed="true")

        self.assertNotEqual(rejected.returncode, 0, rejected.stdout)
        self.assertEqual(self.remote_main(), advanced)
        self.assertEqual(self.remote_tags(), "")
        self.assertEqual(self.remote_refs(), refs)

    def test_main_advance_between_validation_and_push_rejects_the_tag(self) -> None:
        # The step reads remote main before it prepares the tag. This hook lets a
        # concurrent push advance main after that read and before the tag push,
        # which is where a separate tag push would publish a stale tag.
        git(self.workspace, "push", "-q", "origin", f"{self.commit}:refs/heads/main")
        editor = checkout(self.origin, self.commit, self.directory / "editor-race")
        (editor / "project.yml").write_text("unrelated\n", encoding="utf-8")
        git(editor, "commit", "-qam", "fix: unrelated change")
        advanced = git(editor, "rev-parse", "HEAD")

        def advance_before_send(publisher: Path) -> None:
            hook = publisher / ".git" / "hooks" / "pre-push"
            hook.write_text(
                "#!/usr/bin/env bash\nset -euo pipefail\n"
                f'git -C {editor} push -q {self.origin} HEAD:refs/heads/main\n',
                encoding="utf-8",
            )
            hook.chmod(0o755)

        rejected = self.publish(pushed="true", before=advance_before_send)

        self.assertNotEqual(rejected.returncode, 0, rejected.stdout)
        self.assertEqual(self.remote_main(), advanced)
        self.assertEqual(self.remote_tags(), "")


if __name__ == "__main__":
    unittest.main()
