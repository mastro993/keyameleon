import os
import subprocess
import tempfile
import textwrap
import unittest
from itertools import takewhile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def workflow_script(step):
    workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    body = workflow.split(f"- name: {step}\n", 1)[1].split("run: |\n", 1)[1]
    lines = takewhile(lambda line: not line.strip() or line.startswith("          "),
                      body.splitlines(keepends=True))
    return textwrap.dedent("".join(lines))


class CIClassificationTests(unittest.TestCase):
    def test_bundled_resource_changes_require_macos_but_docs_do_not(self):
        script = workflow_script("Check whether code changed")
        cases = (
            ("Resources/menu_icon.pdf", "true"),
            ("Keyameleon-icon.icon/icon.json", "true"),
            ("Keyameleon-icon.icon/Assets/keycap.png", "true"),
            ("LICENSE", "true"),
            ("THIRD_PARTY_NOTICES.md", "true"),
            ("docs/testing.md", "false"),
        )
        for path, required in cases:
            for change in ("modify", "delete"):
                with self.subTest(path=path, change=change), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)

                    def git(*args):
                        return subprocess.run(
                            ("git", "-c", "user.name=CI Test", "-c", "user.email=ci@example.invalid",
                             "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", *args),
                            cwd=root, capture_output=True, text=True, check=True,
                        ).stdout.strip()

                    git("init", "--quiet")
                    resource = root / path
                    resource.parent.mkdir(parents=True, exist_ok=True)
                    resource.write_text("before\n", encoding="utf-8")
                    git("add", ".")
                    git("commit", "--quiet", "-m", "Base")
                    base = git("rev-parse", "HEAD")
                    if change == "delete":
                        resource.unlink()
                    else:
                        resource.write_text("after\n", encoding="utf-8")
                    git("add", "-A")
                    git("commit", "--quiet", "-m", "Change")
                    output = root / "output"
                    result = subprocess.run(
                        ("bash", "-c", script), cwd=root, capture_output=True, text=True,
                        env={**os.environ, "BASE_SHA": base, "HEAD_SHA": git("rev-parse", "HEAD"),
                             "GITHUB_OUTPUT": str(output)},
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(output.read_text(encoding="utf-8"), f"macos_required={required}\n")


if __name__ == "__main__":
    unittest.main()
