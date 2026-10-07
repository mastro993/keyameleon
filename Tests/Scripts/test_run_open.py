import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = "/tmp/keyameleon-run-open-test/build/Build/Products/Debug"
OPEN_SCRIPT = r'''
source <(sed -n '/^open_development_app()/,/^}/p' Scripts/run.sh)
PRODUCTS_PATH="$1"
running_path="$2"
log_path="$3"
running_keyameleon_apps() {
    cat "$running_path"
    : > "$running_path"
}
kill() { print -r -- "kill $1" >> "$log_path"; }
open() { print -r -- "open $*" >> "$log_path"; }
sleep() { :; }
functions[/bin/ps]='print -r -- "$PRODUCTS_PATH/Keyameleon.app/Contents/MacOS/Keyameleon"'
open_development_app
'''


class DevelopmentOpenTests(unittest.TestCase):
    def test_cleanup_stops_only_development_executables_in_derived_data(self):
        script = r'''
source <(sed -n '/^kill_leftover_derived_data_keyameleon()/,/^}/p' Scripts/run.sh)
PRODUCTS_PATH=/tmp/keyameleon-cleanup-test/build/Build/Products/Debug
input="$1"
terminated="$2"
functions[/bin/ps]='cat "$input"'
kill() { print -r -- "$1" >> "$terminated"; }
kill_leftover_derived_data_keyameleon
'''
        development = "/tmp/keyameleon-cleanup-test/build/Build/Products/Debug/Keyameleon.app/Contents/MacOS/Keyameleon"
        with tempfile.TemporaryDirectory() as directory:
            process_list = Path(directory) / "processes"
            terminated = Path(directory) / "terminated"
            process_list.write_text(
                f"1 {development}\n"
                f"2 {development} -NSDocumentRevisionsDebugMode YES\n"
                "3 /tmp/keyameleon-cleanup-test/build/Build/Products/Release/Keyameleon.app/Contents/MacOS/Keyameleon\n"
                "4 /Applications/Keyameleon.app/Contents/MacOS/Keyameleon\n"
                f"5 {development}-other\n",
                encoding="utf-8",
            )
            subprocess.run(
                ("zsh", "-c", script, "test", str(process_list), str(terminated)),
                cwd=ROOT, capture_output=True, text=True, check=True,
            )
            self.assertEqual(terminated.read_text(encoding="utf-8"), "1\n2\n")

    def test_open_replaces_only_this_checkouts_debug_app(self):
        app = f"{PRODUCTS}/Keyameleon.app"
        cases = (
            ("installed release", "4242\t/Applications/Keyameleon.app\n", 1, ""),
            ("another build", f"77\t{app}\n4242\t/tmp/other/Keyameleon.app\n", 1, ""),
            ("own build", f"77\t{app}\n", 0, f"kill 77\nopen -n -a {app}\n"),
            ("nothing running", "", 0, f"open -n -a {app}\n"),
        )
        for name, running, status, log in cases:
            with self.subTest(name), tempfile.TemporaryDirectory() as directory:
                running_path = Path(directory) / "running"
                log_path = Path(directory) / "log"
                running_path.write_text(running, encoding="utf-8")
                log_path.touch()
                result = subprocess.run(
                    ("zsh", "-c", OPEN_SCRIPT, "test", PRODUCTS, str(running_path), str(log_path)),
                    cwd=ROOT, capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(log_path.read_text(encoding="utf-8"), log)
                if status:
                    self.assertIn("Keyameleon is already running from", result.stderr)

    def test_lookup_failure_never_opens_app(self):
        script = r'''
source <(sed -n '/^open_development_app()/,/^}/p' Scripts/run.sh)
PRODUCTS_PATH=/tmp/keyameleon-run-open-test
counter_path="$1"
opened_path="$2"
fail_on="$3"
running_keyameleon_apps() {
    local calls="$(cat "$counter_path")"
    calls=$(( calls + 1 ))
    print -r -- "$calls" > "$counter_path"
    if (( calls == fail_on )); then
        return 73
    fi
    (( calls == 1 )) && print -r -- $'99998\t/tmp/keyameleon-run-open-test/Keyameleon.app'
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
