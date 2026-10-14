# Debug builds have their own identity

Debug builds, including Xcode Run, `run.sh open`, and the hosted test app, use
bundle ID `dev.fedemas.keyameleon.debug` and show the name Keyameleon Dev.
Release builds, including every Official Release, keep `dev.fedemas.keyameleon`.
Each identity has its own Input Monitoring row, preferences domain, SwiftData
store, and Log File folder. The folder name follows the bundle ID, never the
display name, so renaming or localizing the app cannot move user data:
`Keyameleon` for the release ID and `Keyameleon Dev` for any other. Only the
release imports the pre-0.4.6 store at `~/Library/Application Support/default.store`.
Even when that file is Keyameleon's (#190), it holds an old release's data, so a
Debug store starts empty.

macOS keeps one Input Monitoring row per bundle ID, and the row matches one
code-signing designated requirement. The release is signed with Developer ID and
Debug with an Apple Development certificate, so with a shared ID only one of the
two read granted at a time. Worse, Restart Keyameleon's stale-row recovery runs
`tccutil reset ListenEvent <bundle ID>`, which wiped the other build's grant
every time, in both directions. The shared ID also handed the release's real data
to unreleased code: a Debug build with a newer schema rewrote the release store,
and release 0.9.0, which knows only schema V1, silently dropped the tables it
did not know when it opened that store, losing App Assignments saved there. Quit
& Reopen relaunches by bundle ID, so it could also open the other build.

This is the third version of a Debug identity. #45 introduced
`dev.fedemas.keyameleon.development`. #157 made it a fully isolated
`Keyameleon (Dev)` with its own lock, Keychain service, and folders. #163 removed
it because "the mechanism is no longer needed", without checking alternating
builds against existing Input Monitoring grants, which its review had asked for.
The one-row-per-bundle-ID rule is a macOS constraint that does not go away, so
do not merge the identities again.

What differs from #157:

- The ID is new. Leftovers of the retired `.development` app stay untouched.
- The Debug bundle is `Keyameleon Dev.app`. System Settings, Finder, and other
  LaunchServices lists name an app after its bundle file, so a display name alone
  would leave both builds listed as Keyameleon. The module and the executable
  inside the bundle stay `Keyameleon` in both.
- Both identities keep the single `/dev/null` lock of
  [ADR 0002](0002-one-keyameleon-instance-per-mac.md). Two running switchers
  would fight over the Input Source, so Debug never runs beside the release.
- The Keychain service name stays the same. Each build uses the integrity key
  only to sign designations in its own store, so whether the two builds see the
  same item changes nothing.

`run.sh reset` erases only the Debug identity. Erasing the release's permission,
preferences, and data needs `run.sh reset --release`. Code that recognizes
Keyameleon itself by bundle ID must accept both IDs.
