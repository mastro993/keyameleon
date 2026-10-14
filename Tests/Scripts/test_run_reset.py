import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELEASE_BUNDLE_ID = "dev.fedemas.keyameleon"
DEBUG_BUNDLE_ID = "dev.fedemas.keyameleon.debug"
# The bundle IDs come from run.sh itself, so the default reset target is under test.
RESET_SCRIPT = r'''
source <(sed -n \
    -e '/^BUNDLE_ID=/p' \
    -e '/^RELEASE_BUNDLE_ID=/p' \
    -e '/^wait_until_no_keyameleon_runs()/,/^}/p' \
    -e '/^registered_keyameleon_apps()/,/^}/p' \
    -e '/^reset_local_state()/,/^}/p' \
    -e '/^delete_legacy_store()/,/^}/p' \
    Scripts/run.sh)
HOME="$1"
dump_path="$2"
log_path="$3"
shift 3
running_path="$HOME/running"
print -r -- $'42\t/Applications/Keyameleon.app' > "$running_path"
# A reset quits only copies of the identity it resets.
running_keyameleon_apps() {
    if [[ "$*" != "$BUNDLE_ID" ]]; then
        print -u2 "queried running apps for: $*"
        return 1
    fi
    cat "$running_path"
    : > "$running_path"
}
LSREGISTER=lsregister_stub
lsregister_stub() {
    if [[ "$1" == -dump ]]; then
        cat "$dump_path"
    else
        print -r -- "lsregister $*" >> "$log_path"
    fi
}
kill() { print -r -- "kill $1" >> "$log_path"; }
# Like the real tool, tccutil cannot resolve the bundle ID once every copy is unregistered.
tccutil() {
    grep -q '^lsregister -u' "$log_path" && return 1
    print -r -- "tccutil $*" >> "$log_path"
}
osascript() {
    while [[ "$1" == -e ]]; do shift 2; done
    print -r -- "remove login items at $*" >> "$log_path"
}
defaults() { print -r -- "defaults $*" >> "$log_path"; }
sleep() { :; }
reset_local_state "$@"
'''


KEYAMELEON_TABLES = (
    "ZPHYSICALKEYBOARDRECORDMODEL",
    "ZMANUALPHYSICALKEYBOARDDESIGNATIONMODEL",
    "Z_PRIMARYKEY",
    "Z_METADATA",
    "Z_MODELCACHE",
    "ACHANGE",
    "ATRANSACTION",
    "ATRANSACTIONSTRING",
)


class ResetLocalStateTests(unittest.TestCase):
    def make_home(self, home, legacy_tables):
        support = home / "Library/Application Support"
        for folder in ("Keyameleon", "Keyameleon Dev"):
            (support / folder).mkdir(parents=True)
            (home / "Library/Logs" / folder).mkdir(parents=True)
        (support / "Other").mkdir()
        for bundle_id in (RELEASE_BUNDLE_ID, DEBUG_BUNDLE_ID):
            (home / "Library/Caches" / bundle_id).mkdir(parents=True)
            (home / "Library/HTTPStorages" / bundle_id).mkdir(parents=True)
        connection = sqlite3.connect(support / "default.store")
        for table in legacy_tables:
            connection.execute(f"CREATE TABLE {table} (Z_PK INTEGER)")
        connection.close()
        (support / "default.store-wal").touch()

        release = home / "stale/Keyameleon.app"
        debug = home / "build/Keyameleon (Dev).app"
        other = home / "other/Other.app"
        for app in (release, debug, other):
            app.mkdir(parents=True)
        (home / "dump").write_text(
            f"path:                       {release} (0x1)\n"
            f"identifier:                 {RELEASE_BUNDLE_ID}\n"
            "--------\n"
            f"path:                       {home}/deleted/Keyameleon.app (0x2)\n"
            f"identifier:                 {RELEASE_BUNDLE_ID}\n"
            "--------\n"
            f"path:                       {debug} (0x3)\n"
            f"identifier:                 {DEBUG_BUNDLE_ID}\n"
            "--------\n"
            f"path:                       {other} (0x4)\n"
            "identifier:                 dev.fedemas.keyameleon.development\n",
            encoding="utf-8",
        )
        (home / "log").touch()
        return support, release, debug

    def reset(self, home, *arguments, script=RESET_SCRIPT):
        return subprocess.run(
            ("zsh", "-c", script, "test", str(home), str(home / "dump"), str(home / "log"), *arguments),
            cwd=ROOT, capture_output=True, text=True, check=False,
        )

    def test_reset_erases_only_the_debug_identity_by_default(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            support, _, debug = self.make_home(home, KEYAMELEON_TABLES)

            result = self.reset(home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Keyameleon Dev local state reset.", result.stdout)
            self.assertEqual(
                (home / "log").read_text(encoding="utf-8"),
                "kill 42\n"
                f"tccutil reset All {DEBUG_BUNDLE_ID}\n"
                f"remove login items at {debug}\n"
                f"defaults delete {DEBUG_BUNDLE_ID}\n"
                f"lsregister -u {debug}\n",
            )
            self.assertFalse((support / "Keyameleon Dev").exists())
            self.assertFalse((home / "Library/Logs/Keyameleon Dev").exists())
            self.assertFalse((home / "Library/Caches" / DEBUG_BUNDLE_ID).exists())
            self.assertFalse((home / "Library/HTTPStorages" / DEBUG_BUNDLE_ID).exists())
            # The release's data and the legacy store it imports stay.
            self.assertTrue((support / "Keyameleon").exists())
            self.assertTrue((home / "Library/Logs/Keyameleon").exists())
            self.assertTrue((home / "Library/Caches" / RELEASE_BUNDLE_ID).exists())
            self.assertTrue((home / "Library/HTTPStorages" / RELEASE_BUNDLE_ID).exists())
            self.assertTrue((support / "default.store").exists())
            self.assertTrue((support / "default.store-wal").exists())

    def run_release_reset(self, home, legacy_tables):
        support, release, _ = self.make_home(home, legacy_tables)

        result = self.reset(home, "--release")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Keyameleon local state reset.", result.stdout)
        self.assertEqual(
            (home / "log").read_text(encoding="utf-8"),
            "kill 42\n"
            f"tccutil reset All {RELEASE_BUNDLE_ID}\n"
            f"remove login items at {home}/deleted/Keyameleon.app {release}\n"
            f"defaults delete {RELEASE_BUNDLE_ID}\n"
            f"lsregister -u {release}\n",
        )
        self.assertFalse((support / "Keyameleon").exists())
        self.assertFalse((home / "Library/Logs/Keyameleon").exists())
        self.assertFalse((home / "Library/Caches" / RELEASE_BUNDLE_ID).exists())
        self.assertFalse((home / "Library/HTTPStorages" / RELEASE_BUNDLE_ID).exists())
        self.assertTrue((support / "Keyameleon Dev").exists())
        self.assertTrue((home / "Library/Logs/Keyameleon Dev").exists())
        self.assertTrue((home / "Library/Caches" / DEBUG_BUNDLE_ID).exists())
        self.assertTrue((home / "Library/HTTPStorages" / DEBUG_BUNDLE_ID).exists())
        self.assertTrue((support / "Other").exists())
        return support

    def test_release_reset_erases_release_state_and_its_legacy_store(self):
        with tempfile.TemporaryDirectory() as directory:
            support = self.run_release_reset(Path(directory), KEYAMELEON_TABLES)
            self.assertFalse((support / "default.store").exists())
            self.assertFalse((support / "default.store-wal").exists())

    def test_release_reset_keeps_a_default_store_with_another_apps_tables(self):
        for name, tables in (
            ("another app", ("ZOTHERMODEL",)),
            ("shared", ("ZPHYSICALKEYBOARDRECORDMODEL", "ZOTHERMODEL")),
            ("shared, plain SQLite table", ("ZPHYSICALKEYBOARDRECORDMODEL", "other_app_records")),
        ):
            with self.subTest(name), tempfile.TemporaryDirectory() as directory:
                support = self.run_release_reset(Path(directory), tables)
                self.assertTrue((support / "default.store").exists())
                self.assertTrue((support / "default.store-wal").exists())

    def test_unreadable_default_store_fails_only_the_release_reset(self):
        for arguments, status in (((), 0), (("--release",), 1)):
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                support = home / "Library/Application Support"
                support.mkdir(parents=True)
                (support / "default.store").write_text("not a database", encoding="utf-8")
                (home / "dump").touch()
                (home / "log").touch()

                result = self.reset(home, *arguments)

                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual("Could not inspect" in result.stderr, bool(status))
                self.assertEqual("local state reset." in result.stdout, not status)
                self.assertTrue((support / "default.store").exists())

    def test_unknown_argument_changes_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            support, _, _ = self.make_home(home, KEYAMELEON_TABLES)

            result = self.reset(home, "--all")

            self.assertEqual(result.returncode, 64)
            self.assertIn("usage: run.sh reset [--release]", result.stderr)
            self.assertEqual((home / "log").read_text(encoding="utf-8"), "")
            self.assertTrue((support / "Keyameleon").exists())
            self.assertTrue((support / "Keyameleon Dev").exists())

    def test_unregister_failure_stops_the_reset(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            support, _, debug = self.make_home(home, ())
            script = RESET_SCRIPT.replace(
                "        print -r -- \"lsregister $*\" >> \"$log_path\"\n",
                "        return 1\n",
            )

            result = self.reset(home, script=script)

            self.assertEqual(result.returncode, 1)
            self.assertIn(f"Could not unregister {debug}", result.stderr)
            self.assertNotIn("local state reset.", result.stdout)
            self.assertFalse((support / "Keyameleon Dev").exists())

    def test_permission_reset_failure_still_erases_state(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            support, _, _ = self.make_home(home, ())
            script = RESET_SCRIPT.replace(
                "    grep -q '^lsregister -u' \"$log_path\" && return 1\n",
                "    return 1\n",
            )

            result = self.reset(home, script=script)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Could not reset privacy permissions", result.stderr)
            self.assertIn(f"defaults delete {DEBUG_BUNDLE_ID}", (home / "log").read_text(encoding="utf-8"))
            self.assertFalse((support / "Keyameleon Dev").exists())


if __name__ == "__main__":
    unittest.main()
