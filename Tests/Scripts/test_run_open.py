import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class DevelopmentOpenTests(unittest.TestCase):
    def test_cleanup_stops_only_development_executables_in_derived_data(self):
        script = r'''
source <(sed -n '/^kill_leftover_derived_data_keyameleon()/,/^}/p' Scripts/run.sh)
DERIVED_DATA_PATH=/tmp/keyameleon-cleanup-test/build
input="$1"
terminated="$2"
functions[/bin/ps]='cat "$input"'
kill() { print -r -- "$1" >> "$terminated"; }
kill_leftover_derived_data_keyameleon
'''
        development = "/tmp/keyameleon-cleanup-test/build/Build/Products/Debug/Keyameleon (Dev).app/Contents/MacOS/Keyameleon (Dev)"
        with tempfile.TemporaryDirectory() as directory:
            process_list = Path(directory) / "processes"
            terminated = Path(directory) / "terminated"
            process_list.write_text(
                f"1 {development}\n"
                f"2 {development} -NSDocumentRevisionsDebugMode YES\n"
                "3 /tmp/keyameleon-cleanup-test/build/Build/Products/Release/Keyameleon.app/Contents/MacOS/Keyameleon\n"
                "4 /Applications/Keyameleon (Dev).app/Contents/MacOS/Keyameleon (Dev)\n"
                f"5 {development}-other\n",
                encoding="utf-8",
            )
            subprocess.run(
                ("zsh", "-c", script, "test", str(process_list), str(terminated)),
                cwd=ROOT, capture_output=True, text=True, check=True,
            )
            self.assertEqual(terminated.read_text(encoding="utf-8"), "1\n2\n")

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
