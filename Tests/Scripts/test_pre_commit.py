import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / ".githooks" / "pre-commit"
LIMIT_BYTES = 20_000


class PreCommitTokenLimitTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.git("init", "-q")

    def git(self, *args):
        subprocess.run(("git", *args), cwd=self.repo, check=True, capture_output=True)

    def stage(self, path, content):
        file = self.repo / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(content)
        self.git("add", path)

    def run_hook(self):
        return subprocess.run(
            ("python3", HOOK), cwd=self.repo, capture_output=True, text=True,
        )

    def test_rejects_staged_authored_file_over_limit_with_split_instructions(self):
        self.stage("Sources/Big.swift", b"a" * (LIMIT_BYTES + 1))

        result = self.run_hook()

        self.assertEqual(result.returncode, 1)
        self.assertIn("Sources/Big.swift: 5,001 tokens (20,001 bytes)", result.stderr)
        self.assertIn("Move each group into its own file", result.stderr)

    def test_allows_limit_binary_exempt_and_unstaged_content(self):
        self.stage(".gitattributes", b"gen/** linguist-generated\nvendor/** linguist-vendored\n")
        self.stage("Sources/AtLimit.swift", b"a" * LIMIT_BYTES)
        self.stage("Resources/image.png", b"\0" * (LIMIT_BYTES * 2))
        self.stage("gen/Output.swift", b"a" * (LIMIT_BYTES * 2))
        self.stage("vendor/skill.md", b"a" * (LIMIT_BYTES * 2))
        self.stage("Sources/Edited.swift", b"small")
        (self.repo / "Sources/Edited.swift").write_bytes(b"a" * (LIMIT_BYTES * 2))

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_repository_exempts_codegen_lockfiles_and_vendored_skills(self):
        paths = (
            "Keyameleon.xcodeproj/project.pbxproj",
            "Resources/Localization/Localizable.xcstrings",
            "design/design.pen",
            "skills-lock.json",
            ".agents/skills/swiftui-expert-skill/references/view-structure.md",
        )
        output = subprocess.run(
            ("git", "check-attr", "linguist-generated", "linguist-vendored", "--", *paths),
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout

        exempt = {line.split(": ")[0] for line in output.splitlines() if line.endswith(": set")}
        self.assertEqual(exempt, set(paths))


if __name__ == "__main__":
    unittest.main()
