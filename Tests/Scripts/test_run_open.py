import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class DevelopmentOpenTests(unittest.TestCase):
    def test_lookup_failure_never_opens_app(self):
        script = r'''
source <(sed -n '/^open_development_app()/,/^}/p' Scripts/run.sh)
PRODUCTS_PATH=/tmp/keyameleon-run-open-test
counter_path="$1"
opened_path="$2"
fail_on="$3"
development_keyameleon_pids() {
    local calls="$(cat "$counter_path")"
    calls=$(( calls + 1 ))
    print -r -- "$calls" > "$counter_path"
    if (( calls == fail_on )); then
        return 73
    fi
    (( calls == 1 )) && print -r -- 99998
    return 0
}
kill() { return 0; }
open() { print opened > "$opened_path"; }
sleep() { :; }
open_development_app
'''
        for fail_on in (1, 2, 3):
            with self.subTest(fail_on=fail_on), tempfile.TemporaryDirectory() as directory:
                counter = Path(directory) / "calls"
                opened = Path(directory) / "opened"
                counter.write_text("0", encoding="utf-8")
                result = subprocess.run(
                    ("zsh", "-c", script, "test", str(counter), str(opened), str(fail_on)),
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(counter.read_text(encoding="utf-8"), f"{fail_on}\n")
                self.assertFalse(opened.exists())


if __name__ == "__main__":
    unittest.main()
