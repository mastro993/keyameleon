import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESET_SCRIPT = r'''
source <(sed -n \
    -e '/^wait_until_no_keyameleon_runs()/,/^}/p' \
    -e '/^registered_keyameleon_apps()/,/^}/p' \
    -e '/^reset_local_state()/,/^}/p' \
    Scripts/run.sh)
BUNDLE_ID=dev.fedemas.keyameleon
HOME="$1"
dump_path="$2"
log_path="$3"
running_path="$HOME/running"
print -r -- $'42\t/Applications/Keyameleon.app' > "$running_path"
running_keyameleon_apps() {
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
tccutil() { print -r -- "tccutil $*" >> "$log_path"; }
defaults() { print -r -- "defaults $*" >> "$log_path"; }
sleep() { :; }
reset_local_state
'''


class ResetLocalStateTests(unittest.TestCase):
    def run_reset(self, home, legacy_tables):
        support = home / "Library/Application Support"
        (support / "Keyameleon").mkdir(parents=True)
        (home / "Library/Logs/Keyameleon").mkdir(parents=True)
        (support / "Other").mkdir()
        connection = sqlite3.connect(support / "default.store")
        for table in legacy_tables:
            connection.execute(f"CREATE TABLE {table} (Z_PK INTEGER)")
        connection.close()
        (support / "default.store-wal").touch()

        stale = home / "stale/Keyameleon.app"
        stale.mkdir(parents=True)
        other = home / "other/Other.app"
        other.mkdir(parents=True)
        dump = home / "dump"
        dump.write_text(
            f"path:                       {stale} (0x1)\n"
            "identifier:                 dev.fedemas.keyameleon\n"
            "--------\n"
            f"path:                       {home}/deleted/Keyameleon.app (0x2)\n"
            "identifier:                 dev.fedemas.keyameleon\n"
            "--------\n"
            f"path:                       {other} (0x3)\n"
            "identifier:                 dev.fedemas.keyameleon.development\n",
            encoding="utf-8",
        )
        log = home / "log"
        log.touch()
        result = subprocess.run(
            ("zsh", "-c", RESET_SCRIPT, "test", str(home), str(dump), str(log)),
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            log.read_text(encoding="utf-8"),
            "kill 42\n"
            f"lsregister -u {stale}\n"
            "tccutil reset All dev.fedemas.keyameleon\n"
            "defaults delete dev.fedemas.keyameleon\n",
        )
        self.assertFalse((support / "Keyameleon").exists())
        self.assertFalse((home / "Library/Logs/Keyameleon").exists())
        self.assertTrue((support / "Other").exists())
        return support

    def test_reset_erases_keyameleon_state_and_its_legacy_store(self):
        with tempfile.TemporaryDirectory() as directory:
            support = self.run_reset(Path(directory), (
                "ZPHYSICALKEYBOARDRECORDMODEL",
                "ZMANUALPHYSICALKEYBOARDDESIGNATIONMODEL",
                "Z_PRIMARYKEY",
                "Z_METADATA",
                "ACHANGE",
            ))
            self.assertFalse((support / "default.store").exists())
            self.assertFalse((support / "default.store-wal").exists())

    def test_reset_keeps_a_default_store_with_another_apps_tables(self):
        for name, tables in (
            ("another app", ("ZOTHERMODEL",)),
            ("shared", ("ZPHYSICALKEYBOARDRECORDMODEL", "ZOTHERMODEL")),
        ):
            with self.subTest(name), tempfile.TemporaryDirectory() as directory:
                support = self.run_reset(Path(directory), tables)
                self.assertTrue((support / "default.store").exists())
                self.assertTrue((support / "default.store-wal").exists())

    def test_unregister_failure_stops_the_reset(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            stale = home / "stale/Keyameleon.app"
            stale.mkdir(parents=True)
            (home / "Library/Application Support/Keyameleon").mkdir(parents=True)
            dump = home / "dump"
            dump.write_text(
                f"path: {stale} (0x1)\nidentifier: dev.fedemas.keyameleon\n",
                encoding="utf-8",
            )
            log = home / "log"
            log.touch()
            script = RESET_SCRIPT.replace(
                "        print -r -- \"lsregister $*\" >> \"$log_path\"\n",
                "        return 1\n",
            )
            result = subprocess.run(
                ("zsh", "-c", script, "test", str(home), str(dump), str(log)),
                cwd=ROOT, capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn(f"Could not unregister {stale}", result.stderr)
            self.assertEqual(log.read_text(encoding="utf-8"), "kill 42\n")
            self.assertTrue((home / "Library/Application Support/Keyameleon").exists())


if __name__ == "__main__":
    unittest.main()
