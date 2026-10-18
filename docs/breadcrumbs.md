# Breadcrumbs

A chronological work log, newest first: what changed, how it was diagnosed, and
what was tried. Entries are history and may describe behavior that has since
been replaced. For current behavior, read [`choices.md`](choices.md).

## 2026-10-18 — Shortcuts actions and URL scheme (#196)

- Five App Intents (Pause, Resume, Pause or Resume, Select Input Source, Get
  Active Keyboard and Input Source) and a `keyameleon://` URL scheme share
  `AutomationCommand`. Debug registers `keyameleon-dev://` (ADR 0008).
  A URL-only `set-external-change-response` sets the External Change Response.
- `?name=U.S.` failed on an Italian Mac, where macOS names the layout `USA`.
  `?id=` now also takes the short identifier (`US`), which is the same in every
  language; one that fits two Input Sources selects none.
- An automation selection is an External Input Source Change, chosen over an
  always-on hold so the External Change Response stays the only hold rule.
- The App Intents metadata processor failed with "'LocalizedStringResource'
  must be initialized with a call to its initializer or a string literal" for
  generated string symbols, so intent files use literal manual keys.
- The Raycast extension and the website integrations section live outside
  this repository.

## 2026-10-16 — Encode agent corrections in lint, tests, and types

- Recurring human corrections after agent PRs clustered around Debug/Release
  identity (#157 → #163 → #191), SwiftUI `Picker` in Settings (#166 → #184),
  legacy-store trust (#172 / #190), a capitalized Sparkle feed path (#115),
  `CFArrayGetValueAtIndex` in optimized builds (#78), and Input Monitoring
  relaunch flags (#171). AGENTS.md already listed generic SwiftUI style, which
  did not stop those product failures.
- SwiftLint custom rules now reject `ObservableObject`, GCD, `String(format:)`,
  SwiftUI `Picker(`, and `CFArrayGetValueAtIndex`. `test_source_policy.py`
  checks the identity split, lowercase feed path, `PopUpPicker`, hosted-test
  skip, and relaunch argument, and CI runs those tests on Ubuntu on every
  pull request. The one production `String(format:)` (Bluetooth address bytes)
  moved onto `PhysicalKeyboardIdentity.bluetoothAddress(fromAddressData:)`.
- AGENTS.md now holds only invariants the linter cannot see: copy matching the
  UI, persistence fail-closed, the identity ladder, and verifying bot findings
  against ADRs.

## 2026-10-14 — Debug builds get their own identity again

- Debug and the installed release shared `dev.fedemas.keyameleon` but were
  signed differently (Developer ID vs Apple Development). macOS keeps one Input
  Monitoring row per bundle ID, matched to one designated requirement, so only
  one build read granted, and Restart Keyameleon's stale-row
  `tccutil reset ListenEvent` wiped the other build's grant. The shared store let
  a Debug build with a newer schema rewrite the release's data; release 0.9.0
  then dropped the tables it did not know, losing App Assignments.
- Debug is now `dev.fedemas.keyameleon.debug`, shown as Keyameleon (Dev), with
  `Keyameleon Dev` data and logs folders chosen from the bundle ID
  (`AppBuildIdentity`). Only the release imports the legacy
  `Application Support/default.store`. #190 already skips a file that is not
  Keyameleon's, but a Keyameleon file there is an old release's data, which a
  fresh Debug folder would otherwise copy.
- Debug's bundle is `Keyameleon (Dev).app`: System Settings names an app after its
  bundle file, so a display name alone left two rows called Keyameleon. The
  module stays `Keyameleon`. Unlike #157, the ID is new rather than
  `.development`, and the single `/dev/null` lock stays shared, so the two
  builds never run together.
- `run.sh reset` now erases only the Debug identity; `reset --release` is
  required for the release. `run.sh open` checks both IDs before launching, so it
  refuses while the release runs instead of waiting for a blocked launch.
  `run.sh test` builds into `build/test`, so it no longer replaces the signed app
  and its grant, and unregisters that test host afterwards so Quit & Reopen
  cannot pick it; CI's package cache moved with it.
- Hosted tests now run under the Debug identity, so they no longer touch the
  release's defaults domain.
- ADR 0008 records the reasons, so the identities are not merged a third time.

## 2026-10-14 — Import the legacy store only when it is Keyameleon's

- When `Keyameleon/default.store` was missing, `PhysicalKeyboardStoreMigration`
  copied whatever sat at SwiftData's shared default path,
  `Application Support/default.store`. Keyameleon is not sandboxed, so any other
  non-sandboxed SwiftData app can own that file; on the developer's Mac it held
  another app's tables (`ZAPIREQUESTMODEL` plus Core Data's own).
- With schema V1 the copy opened quietly as Keyameleon's store. With a staged
  V1→V2 migration plan it fails with NSCocoaErrorDomain 134504, "Cannot use
  staged migration with an unknown model version", and saved keyboards stay
  unavailable on every launch; Retry cannot help.
- The staged snapshot is now checked with the table rule that
  `run.sh reset_local_state` already used: `ZPHYSICALKEYBOARDRECORDMODEL` must
  exist and every other non-`sqlite_*` table must be Keyameleon's or Core
  Data's own. Otherwise the snapshot is discarded, one warning line is logged,
  and SwiftData creates a fresh store.
- Checking the snapshot instead of the legacy file keeps the foreign file to
  the one read-only open the backup already made, and the check sees exactly
  the bytes that would be imported.
- Every release before 0.4.6 kept only the two Keyameleon tables in that file;
  Diagnostic Data (0.1.0–0.3.x) used its own `DiagnosticData.store`. So the
  allowlist accepts every real legacy store.
- A store mixing Keyameleon's tables with another app's is not imported: its
  model metadata may be the other app's, and the copy would bring that app's
  data along. `run.sh reset` therefore no longer fails on such a file, since
  launch leaves it alone too. The script now runs the app's exact query instead
  of a two-digit code, so the rule has one wording in both places.
- New tests build a foreign and a mixed SwiftData store at the legacy path,
  plus raw SQLite stores for the empty, Core-Data-only and `sqlite_sequence`
  cases. Against the old code, every skip case imported the file.

## 2026-10-12 — App Assignments (#187)

- Keyameleon now switches per app as well as per keyboard. An App Assignment
  wins over the Keyboard Assignment while its app is frontmost; the result is
  the Wanted Input Source, which replaced `WantedKeyboardAssignment` throughout
  `ActivityTriggeredSwitching` ([ADR 0007](adr/0007-app-assignments-override-keyboard-assignments.md)).
- App Activations come from `NSWorkspace.didActivateApplicationNotification`
  through `FrontmostAppObserving`; Keyameleon's own activation is ignored so
  editing in Settings never switches. `FrontmostAppAssignments` keeps the
  frontmost app and a cache of saved App Assignments, read once per change.
- The SwiftData store moved to schema version 2 with a lightweight stage that
  only adds `AppAssignmentModel`. A test opens a real version 1 store.
- `ActivityTriggeredSwitching.swift` hit the SwiftLint file and type-body
  limits, so warning bookkeeping moved into `SwitchingWarnings` and unavailable
  reason bookkeeping into `SwitchingUnavailableReason`. `makeLiveComposition`
  takes the shared persistence session instead of three stores.
- Hold notices now say a hold also ends when you switch apps; the four strings
  were retranslated.
- Rejected: a per-keyboard, per-app matrix, and waiting for the next key press
  before applying an App Assignment. Website Assignments are #188.

## 2026-10-12 — Remove unused code

- Manual Physical Keyboard Designation, Replace Saved Physical Keyboard, and
  Forget lost their Settings entry points in #150 and kept only model seams.
  Their creation flows are gone: the designation session in `SetupModel`, the
  replace, forget, and designate cases of `SavedPhysicalKeyboardChange`,
  `ManualPhysicalKeyboardDesignationEvidenceRules`,
  `replaceActivePhysicalKeyboard`, and the `deleteRecord`, `save`, and `delete`
  store methods. `SavedPhysicalKeyboardChanges` now writes records only.
- Designations saved by earlier versions are still read and authenticated, so a
  keyboard someone already vouched for stays assignable. `ManualDesignationTests`
  now seeds that saved evidence instead of driving the removed flow.
- Also removed: `InputSourceMismatch`, `isFixedBuiltInIdentity`, `panePadding`,
  `PreviewFixtures.fixedDate` and its unused `designationInProgress` state,
  `filteredInputSources`, the `CardSurface` color, properties that only tests
  read (`actionTitles`, `allowsActivityTriggeredSwitching`, both
  `supportsRetryNow`, and three `UpdatePolicy` flags that Sparkle never read; the
  Info.plist keys still enforce them), a tracked `__pycache__` file, and
  `assets/.gitkeep`.

## 2026-10-11 — The app speaks the website's languages

- Keyameleon now ships Arabic, French, Italian, Japanese, Korean, Simplified
  Chinese, Spanish, and Traditional Chinese, the languages of the website.
  Strings moved into `Resources/Localization` string catalogs with manual keys,
  and code uses the generated symbols.
- Models that hand `String`s to AppKit or tests (menu actions, notices,
  persistence errors) resolve them with `String(localized:)`. Sentences that
  were assembled from fragments (" (Ignored)", "The input source", reason +
  "Switching resumes automatically.") became whole strings per case.
- macOS terms were matched against the system's own `.loctable` translations
  rather than guessed; for example, Spanish macOS 26 calls Input Monitoring
  "Monitorización de los dispositivos de entrada".
- XcodeGen lists a catalog's languages in `knownRegions` only when the catalog
  sits in a source folder, hence `Resources/Localization`.
- The test action pins English; on a Mac set to Italian, copy assertions
  failed otherwise.
- Removed four unused confirmation-message builders from `SetupModel` rather
  than translate them.

## 2026-10-11 — Rebuild keyameleon.app after publishing

- keyameleon.app (`mastro993/Keyameleon-web`) prerenders the latest release at
  build time, so its HTML went stale until the site was rebuilt
  (Keyameleon-web#46).
- `publish` now ends with **Rebuild keyameleon.app**, which POSTs to the
  Cloudflare Workers Builds deploy hook in `KEYAMELEON_WEB_DEPLOY_HOOK`. It runs
  after the Homebrew cask, so the release and DMG are already live. It uses
  `continue-on-error` and skips with a warning when the secret is missing.
- Rejected: a separate `on: release` workflow. The release is published with
  `GITHUB_TOKEN`, and GitHub does not start workflows from its events.

## Archive

- [2026-10-01 to 2026-10-10](breadcrumbs/2026-10-01-to-10.md)
- [2026-09-24 to 2026-09-28](breadcrumbs/2026-09-24-to-28.md)
- [2026-09-20 to 2026-09-23](breadcrumbs/2026-09-20-to-23.md)
- [2026-08-14 to 2026-08-27](breadcrumbs/2026-08-14-to-27.md)
- [2026-08-10 to 2026-08-13](breadcrumbs/2026-08-10-to-13.md)
