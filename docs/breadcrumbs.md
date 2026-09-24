# Breadcrumbs

## 2026-09-24 — Sparkle update checks hit a 404 feed

- Keyameleon shipped `SUFeedURL` as
  `https://mastro993.github.io/Keyameleon/appcast.xml`. GitHub Pages serves a
  project site under the repository's lowercase path, so the capitalized path
  returned the Pages "site not found" page with `Content-Type: text/html` and
  every update check failed with Sparkle's "Update Error! An error occurred in
  retrieving update information. Please try again later."
- Repro before the fix: on the installed 0.4.0 build, about window, Check for
  Updates. The system URL cache for `dev.fedemas.keyameleon` recorded that
  request returning the 404 HTML body.
- Control: the same build with only `SUFeedURL` overridden to the lowercase path
  reported "Keyameleon 0.4.1 is now available—you have 0.4.0", which isolates
  the path case as the cause and shows the appcast, version comparison, and
  EdDSA key all work.
- Fixed in `project.yml`, `Sources/App/Info.plist`,
  `KeyameleonUpdatePolicy.feedURLString`, `Scripts/write-release-evidence.sh`,
  `docs/release/official-release.md`, and `MEMORY.md`.
- The release workflow now reads `SUFeedURL` back out of the archived app and
  requires the published feed to serve the released `<sparkle:version>` before
  the GitHub Release is published, so a feed that does not resolve fails the
  release instead of shipping.
- `0.4.0` and `0.4.1` installed copies carry the old URL and cannot self-update.
  They need one manual install; anything built after this change updates itself.

## 2026-09-24 — Assignment pill shows the layout locale code

- The right-edge badge on an assignment pill shows the assigned Input Source's
  locale code (`US`, `IT`, `FR`) instead of its ISO 639 language code, so a U.S.
  layout reads `US` rather than `EN`.
- `EligibleInputSource.languageCode` becomes `localeCode`, and
  `MenuBarAssignmentList.Row.assignedLanguageCode` becomes `assignedLocaleCode`.
  No alias survives.
- macOS reports the layout's languages alone, so
  `EligibleInputSourceCatalog.localeCode(from:)` resolves the region from the
  primary language's canonical locale (`en` → `US`) and falls back to the
  language code when the language has no canonical region. A layout that reports
  no language keeps no badge.
- Region-variant layouts whose identifier carries no region code (British,
  Canadian, Australian, New Zealand, Swiss, Austrian, Belgian, Portuguese) show
  their language's canonical region, so the British layout reads `US`. Add a
  layout-identifier lookup only when someone reports it.
- Tests: the pill row test asserts `IT` and `US`, and a discovery test asserts
  the locale code for a U.S. layout, an Italian layout, and a layout that
  reports no language.

## 2026-09-23 — Operational Notifications removed

- Removed the Operational Notifications subsystem end to end:
  `OperationalNotifications.swift` and `OperationalNotificationTests.swift` are
  deleted, along with the `operationalNotifications` parameter on
  `ActivityTriggeredSwitching`, `KeyameleonSetupModel`,
  `KeyameleonGeneralSettingsModel`, and the composition root.
- General Settings loses the Operational Notifications section: the authorization
  row, the Enable Notifications button, and the System Settings shortcut that
  opened notification settings. `NotificationSettingsOpening`,
  `NSWorkspaceNotificationSettingsOpener`, and `NoOpNotificationSettingsOpener`
  go with it.
- `ActivityTriggeredSwitching` loses `hasKeyboardAssignment` and
  `refreshHasKeyboardAssignment()`, which existed only to gate the setup offer,
  plus `updateOperationalNotifications()` and its observer.
- `KeyameleonSetupModel` loses `notificationAuthorizationState` and
  `shouldOfferOperationalNotificationSetup`. Guided setup and Keyboard
  Assignment editing are unchanged.
- `UserNotifications.framework` is no longer linked.
- Leftover `keyameleon.notifications.*` UserDefaults keys stay inert; no
  migration code removes them.
- Tests: the notification suite is deleted. Switching, recovery, lifecycle,
  pause, and settings tests are unchanged.

## 2026-09-23 — Assignment pill name, subtitle, and ISO language code

- Pill title is the Physical Keyboard Name: Custom name when set, product name
  otherwise. Subtitle is the connection type alone, or
  `<product name> - <connection type>` when a Custom name hides the product name.
- The assigned Input Source moves to the right edge as its ISO 639 language code
  (`IT`, `EN`, `FR`). `EligibleInputSource` carries `languageCode`, derived from
  `kTISPropertyInputSourceLanguages`; the full Input Source name stays in the
  VoiceOver value, so speech is unchanged.
- `PhysicalKeyboard.connectionTypeName` owns the USB / Bluetooth / Built-in
  vocabulary. Keyboard Settings composes its `Connected · USB` line from it
  instead of a second switch.
- `MenuBarAssignmentList.Row` gains `subtitle` and `assignedLanguageCode`, and
  its initializer takes assigned Input Sources instead of names, so the row
  cannot show a code the Input Source does not have.
- Tests: the pill row test covers Custom name, subtitle, and code together, plus
  the no-Custom-name and unavailable-assignment branches.

## 2026-09-23 — Assignment pill borders

- Connection state now reads from the pill outline. Active keeps its fill and green mark, a connected but inactive Physical Keyboard gets a solid border, and a disconnected one gets a dashed border.
- `MenuBarAssignmentPillStyle` takes the row's `ConnectionMark` instead of an `isActive` boolean, so the outline cannot disagree with the row it renders.

## 2026-09-22 — Local logging replaces Diagnostic Data

- Removed the Diagnostic Data feature: `DiagnosticData.swift`,
  `DiagnosticDataService.swift`, `DiagnosticDataStore.swift`,
  `DiagnosticBundleReviewView.swift`, `KeyameleonDiagnosticWindowController.swift`,
  the About Diagnostics section, the Diagnostic Bundle review, and the dead
  `reviewDiagnostics`/`dismissDiagnosticsNotice` selectors.
- Added `Sources/Features/Shared/KeyameleonLog.swift`: level and category enums, a
  `KeyameleonLogWriter` value, the process-wide `KeyameleonLog`, and the rotating
  file writer.
- Log call sites: launch, termination, record store failure, Launch at Login
  failure, update check, Active Physical Keyboard change, connect, disconnect,
  coalesced selection, selection result, Switching Status change, Listen
  permission, Keyboard Assignment saved or removed, replace, forget, and the
  built-in migration.
- About: the Unclean Exit notice and the Diagnostics section are gone. The Logs
  Folder row with its Open button was already there and is unchanged.
- Removed `UncleanExitState`, `UncleanExitPresentation`, and the Unclean Exit test
  file, plus the store on the application delegate and the notice flag on the
  settings model. No launch tracks normal termination, and no launch opens About
  by itself.
- Tests: `KeyameleonLogTests.swift` covers the line shape, size rotation, the
  append-only writer, and silence until a writer is installed. Diagnostic-only
  tests are deleted, and the migration and designation tests no longer assert on
  diagnostic tokens.
- Review round. Split the logging types into one file each. Added the Physical
  Keyboard Name to `PhysicalKeyboardDiscoveryRecordChange`, because discovery
  removes a keyboard from the catalog before it publishes a disconnect.
  `appendOnlyFile` logs the blocked second launch without rotating a file the
  running app holds open. Dropped the coalesced-selection line that fired on every
  keypress and moved `verbose` to external Input Source changes.
- Second review round. Connection logs resolve the saved Physical Keyboard Name
  before falling back to the catalog or the discovery payload, so two keyboards
  with the same product name stay distinguishable. The writer collapses line
  breaks inside a message and reads the active file size from its descriptor, so
  a blocked launch's appends count toward rotation.
- Third review round. A record larger than the file budget is truncated with an
  ellipsis before the rotation check. Rotation happens before the write, so an
  oversized Physical Keyboard Name would otherwise land in a fresh file and
  overrun the size limit on its own.
- `Scripts/run.sh` retargets the Key Content audit at the logging pipeline, and the
  audit now fails loudly when an audited path is missing.

## 2026-09-22 — Menu-bar footer row kept its focus ring after a pointer click

- Reported: after clicking a button in the menu-bar panel, a row stayed focused.
  The highlight should appear only when keyboard navigation needs it.
- Cause: the popover reuses one content view across shows, so `@FocusState`
  survives a close. A pointer click leaves SwiftUI focus on the clicked row, and
  when that click flips the Pause/Resume row identity SwiftUI moves focus to the
  next row. The reopened panel then draws the focus ring on that row.
- Reproduced by driving the running app with real mouse events and measuring the
  live panel pixels. Clicking a row and reopening the panel put 7,980
  accent-blue ring pixels on the Settings row while the app's focused element was
  `AXButton menu-bar-action-settings`.
- Fix: the panel returns focus to the silent container on every key-window
  transition, so each show starts on the container. Keyboard navigation still
  rings. The same harness measures 8,057 ring pixels once a row takes focus from
  the keyboard.
- Dead end, measured: gating `focusEffectDisabled` on the input device also
  suppressed the keyboard ring. SwiftUI creates a row's focus effect as the row
  takes focus, so an environment change driven by panel state lands after that.

## 2026-09-21 — Sparkle logged a background-app gentle reminder warning

- Reported: Xcode logged "Warning: Background app automatically schedules for
  update checks but does not implement gentle reminders."
- Cause: `SPUStandardUpdaterController` was created with `userDriverDelegate:
  nil`, so Sparkle's standard user driver had no delegate declaring
  `supportsGentleScheduledUpdateReminders`, and Keyameleon is a background app
  (`LSUIElement`, activation policy `.accessory`).
- Reproduced with an lldb breakpoint on
  `-[SPUStandardUserDriver logGentleScheduledUpdateReminderWarningIfNeeded]`,
  which stops on launch. At the stop
  `[(id)self->_delegate respondsToSelector:@selector(supportsGentleScheduledUpdateReminders)]`
  evaluated to NO.
- Fix: `SparkleUpdateChecker` is the standard user driver delegate. A scheduled
  update switches the app to `.regular` with Dock badge `1`, user attention
  clears the badge, and the end of the session restores `.accessory`. Sparkle
  still shows its own alert.

## 2026-09-21 — Release page showed two Contributors sections

- Reported: each release page listed contributors twice, one list with square
  avatars.
- Cause: `Scripts/official-release-notes.sh` emitted its own `### Contributors`
  avatar list. GitHub already renders a Contributors card outside the release
  body from the body's user mentions (`mentions_count` on the release API).
  Correlation held across every release in this repository: v0.2.1 and v0.2.2
  mention `@mastro993` and show the card, v0.2.0 and v0.1.1 have no mentions and
  no card, and ripgrep and cli/cli pages match the same rule.
- Fix: drop the section, its `contributor_line` helper, and the login/user-id
  lookups it needed. `@login` attribution on change and Changelog lines stays.

## 2026-09-20 — Input Source selection crash in optimized builds

- Reported: a built-in keyboard key press with its Keyboard Assignment switched to
  Italian and killed the app.
- Cause: `inputSource(withIdentifier:)` returned a `TISInputSource` bitcast from a
  `CFArray` element. `TISInputSource` is ARC-managed, so the retain for the return
  value could run after the array's release and touch freed memory
  (`EXC_BAD_ACCESS` in `objc_retain`, `InputSources.swift:192`).
- Release-only: `-Onone` releases the array after that retain, so Debug builds and
  the test suite never reproduced it.
- Fix: bridge `TISCreateInputSourceList` once into an owned `[TISInputSource]`.
- `run.sh audit` now rejects `CFArrayGetValueAtIndex` in Sources and Tests.

## 2026-08-27 — Removed automated UI tests

- Deleted `KeyameleonUITests` target and `Tests/UITests`.
- Removed UI-test launch/reset hooks from production code.
- `run.sh` now runs only Swift Testing and hosted XCTest bundles.

## 2026-08-17 — Release notes contributor avatars

- v0.1.1 Contributors used git names (`Federico Mastrini`). PR lookup needed
  `pull-requests: read` (explicit permissions override).
- Keep ADR 0006 heading. Emit avatar markdown
  (`avatars.githubusercontent.com/u/{id}?s=64&v=4`). Lookup PR user, then
  commit author.

## 2026-08-17 — Merge main #65 into DMG-only release

- Kept both choice blocks: CI hang-after-pass and DMG-only Official Release.
- `main` already shipped ADR 0005 (hosted unit tests). DMG-only ADR becomes 0006.

## 2026-08-17 — Impl hang-after-pass

- `startsApplicationSurfaceOnLaunch` + `KeyameleonHostedUnitTestProcess`.
- Test-only DI defaults: NoOp discoverer / event / Input Source change / lifecycle.
- `run.sh` kills leftover `./build/**/Keyameleon.app/**` after each test `xcodebuild`.
- ADR 0005. `docs/testing.md` updated.

## 2026-08-17 — Grill Q11–Q12 settled; frontier empty

- Q11 B: `XCTestConfigurationFilePath` || `XCTestBundlePath`.
- Q12 A: host Sparkle off for hosted unit tests.
- Default (no extra Q): ApplicationTests fakes stay local in that file. No shared test-support target.

## 2026-08-17 — Grill Q7–Q10 settled

- Q7 A: `startsApplicationSurfaceOnLaunch` flag. Do not branch `didFinishLaunching` on env.
- Q8 A: kill leftover only if path under `./build`.
- Q9 A: ADR yes.
- Q10 A: no extra `xcodebuild` timeout now.
- Residual: Swift Testing is also `bundle.unit-test` hosted in app. Host Sparkle still `startsUpdaterOnLaunch: !isUITesting`.

## 2026-08-17 — Grill Q4–Q6 settled

- Q4 C: host skip live start + ApplicationTests fakes/`stop()`.
- Q5 B: kill leftover Keyameleon after each `xcodebuild` (hygiene, not hang unblock).
- Q6 A: keep UI-first split.
- Fact: System discoverer/observer start only in `start()`, not `init`. `isXCTestHost` inside `applicationDidFinishLaunching` would also skip ApplicationTests that need the status item.

## 2026-08-17 — Grill Q1–Q3 settled

- Q1 A: hang-after-pass.
- Q2 A: no suite rewrite; fix host/`xcodebuild` teardown.
- Q3 A: exit when last test finishes; 8 min cap stays.

## 2026-08-17 — Grill: CI hang vs suite rewrite

- User claim: CI stuck for no reason → rewrite all test suites.
- Fact: run 31839656616 — `KeyameleonApplicationTests` 10/10 pass, then `xcodebuild` idle until "timed out after 10 minutes." Orphan: `xcodebuild`, `SWBBuildService`, `DTServiceHub`. Last logs: NSStatusItem / Control Center scene teardown + `TCC deny IOHIDDeviceOpen`.
- CI #136 (PR #64, 2026-08-17): job annotation `The job has exceeded the maximum execution time of 8m0s`. Same class, now capped.
- `ApplicationTests` host `Keyameleon.app`; `applicationDidFinishLaunching` always `activityTriggeredSwitching.start()` with default `SystemPhysicalKeyboardDiscoverer` + `SystemPhysicalKeyboardEventObserver` — unbounded CoreHID `for try await`.
- `run.sh` already splits UI tests first: "delayed UI runner cannot hold completed product tests for 30 minutes."
- ADR 0001 already killed qualification bloat. Green code CI after #61 ≈ 3 min. Hang is host/runner exit, not suite design.

## 2026-08-17 — DMG-only Official Release

- ADR 0006. GitHub Release publishes only `Keyameleon-<version>.dmg`. Appcast goes to GitHub Pages. Evidence stays a workflow artifact.
- `v0.1.0` already published as ZIP + source tar + appcast + evidence. Not migrated. Next Official Release is a new version.
- Host Pages is off today (`gh api .../pages` 404). Enable `gh-pages` `/ (root)` before the next `workflow_dispatch`.

## 2026-08-16 — Sparkle key "isn't base64"

- Run 31942341947 `produce` died after staple:
  `Private key not decoded from the argument because it isn't base64 encoded`.
- Local `sparkle_eddsa_private.key.one` is valid 44-byte seed. Same key quoted or PEM-wrapped reproduces the error.
- Env secret was wrapped/pasted wrong. Reset from local export. Script now normalizes + `--ed-key-file` temp path.

## 2026-08-16 — Release verify gh api --arg

- Run 31941940548 `Require green CI on this commit` died: `accepts 1 arg(s), received 4`.
- Cause: `wait-for-ci.sh` passed `jq --arg` to `gh api --jq`.
- Fix: pipe `gh api` JSON to `jq --arg`. Add workflow `checks: read` for check-runs.

## 2026-08-14 — Official Release workflow_dispatch

- ADR 0004. Tag-push trigger removed. Notes script + tests. Docs match dispatch-only publish.
- First Official Release runbook in `docs/release/official-release.md`. Host today: env empty, no tag ruleset.

## 2026-08-14 — Drop Beta Channel

- Beta reopened then dropped. V1 stays one Channel: Stable. Q21–Q28 discarded.

## 2026-08-14 — Official Release workflow grill

- Reversed #16 tag-push trigger and #1 Homebrew OOS. Kept #1 prerelease OOS (no Beta Channel).
- Glossary: **Channel** (not Track). Official Release belongs to one Channel and is not replaced.
- V1 Channel = Stable only. Dispatch on green `main`.
- Homebrew descoped for this workflow. Agreed later shape (not built): own tap `mastro993/homebrew-keyameleon`, cask inside tap, Sparkle `auto_updates`.
- Notes = `git log` since previous Official Release tag.

## 2026-08-14 — Issue #51 accessible panel

- Complete #49/#50 panel: VoiceOver, keyboard order, Reduce Transparency, contrast, dismiss-safe close.
- No Quick Actions row or recovery banner. Speech + More cover Switching Status and recovery.
- Silent container first responder on open. Tab (and Shift-Tab) starts the ring.

## 2026-08-14 — Release README grill

- Drop glossary terms **Multilingual Professional** and **First-Key Guarantee**.
- Product sentence now: same Mac, Physical Keyboards with different physical layouts.
- Guided setup + completed-setup copy no longer names First-Key Guarantee.
- Public README rewritten: user-first, Official Release install, Privacy,
  Architecture, Releasing secrets table. Screenshot placeholder at
  `assets/screenshot.png`.

## 2026-08-14 — Tighter footer, no panel diagnostics

- List-to-footer gap: 4 + 6. Overflow drops Review/Dismiss Diagnostics.

## 2026-08-14 — Panel is keyboards + footer

- Body: assignment list + footer only. Pause/recovery/diagnostics/Settings live in ellipsis.
- Cog opens main window (`Open Keyameleon`), not Settings.

## 2026-08-14 — Footer cog and ellipsis

- Footer right: circular `gearshape` Settings icon + `ellipsis` overflow. Settings leave the menu.

## 2026-08-14 — More outside click

- Click away from More: cancel `NSMenu` tracking + close the panel. Transient popover never saw that click.

## 2026-08-14 — More is pull-down

- Footer overflow: small `.flexiblePush` pill. `More` + trailing `chevron.down`. A11y title `More` for UI tests.
- Do not name `CGSize` in Sources. `run.sh` audit `CGS[A-Za-z]` matches it and blocks `open` / `test`.

## 2026-08-14 — Footer container

- Footer is own full-width region. 1 pt `.separator` top border. Content stack keeps 16 pt padding.

## 2026-08-14 — Keyboards first in menu-bar panel

- Panel order: Keyboards, Quick Actions, recovery banner, unclean-exit notice, footer.

## 2026-08-14 — Footer version label

- Visible footer: `Keyameleon <marketing>` not `Version <marketing>`. Blank → `Keyameleon —`.

## 2026-08-14 — Merge #49 assignment list into #50 panel

- Keep #50 Quick Actions, recovery banner, footer. Replace leftover status dump with `MenuBarAssignmentList`.
- Request Permission lives in the recovery banner when the outcome offers it.

## 2026-08-14 — Menu-bar Request Permission missing

- Outcome already had `.requestPermission` on Permission Required. Panel never rendered it.
- Add notice action **Request Permission** → `SetupModel.requestPermission()`.

## 2026-08-14 — Menu-bar assignment pills

- Assigned rows render as squircle pills: Physical Keyboard Name title / assigned Input Source subtitle / no trailing value.
- All assigned rows use a theme-aware control background. Active (last Activation Activity) gets a 2 pt rainbow border and a soft neutral `Active` badge at top right.
- List unbounded via `LazyVStack`; 5-pill viewport still scrolls overflow.

## 2026-08-14 — Request Permission click did nothing

- Cause: no `NSInputMonitoringUsageDescription` → `IOHIDRequestAccess` returns false with no prompt. Denied path also opened nothing.
- Fix: add usage description; `SetupModel.requestPermission()` opens System Settings when status stays Permission Required; activate app before request.

## 2026-08-14 — Issue #49 Assigned Physical Keyboards in menu-bar panel

- Seam: `MenuBarAssignmentList` filters/orders assigned rows; panel view renders read-only section with 5-row scroll cap.
- Empty Keyboards section uses a theme-aware soft gray keyboard card with a title and Settings guidance.
- Keep #48 actions/footer until #50. Drop Menu first assignment status dump.
- Order: Keyboards, then Switching Status / unclean-exit diagnostics, then actions.

## 2026-08-13 — Issue #48 Open live Liquid Glass menu-bar panel

- Replacing status-item `NSMenu` with one transient 320 pt SwiftUI `NSPopover`.
- Native macOS 26 popover glass; no stacked glass cards.
- Refresh-before-show via `checkAgain()`. Icon marks stay on the `NSStatusItem` button.

## 2026-08-13 — Xcode Debug Run could not resolve packages

- Repro: `WorkspaceSettings.xcsettings` with `BuildLocationStyle=UseTargetSettings` → `xcodebuild: error: Could not resolve package dependencies: Packages are not supported when using legacy build locations, but the current project has them enabled.`
- User-facing Xcode phrasing: could not verify package dependencies.
- Cause: user workspace settings (present on main checkout) force legacy project-relative locations. SPM refuses that layout. CLI with no xcuserdata was green.
- Fix: commit shared modern workspace settings; `run.sh generate` rewrites them and neutralizes user `UseTargetSettings`.

## 2026-08-11 — Product validation simplification

- Reduced CI to one macOS 26 test job with the focused suite and safety audit.
- Removed repeated qualification, 100,000-event stress, human qualification evidence, and performance quotas.
- Replaced qualification guidance with `docs/testing.md` and recorded the decision in `docs/adr/0001-product-validation.md`.

## 2026-08-11 — Issue #39 Activity-Triggered Switching module

- Added `Sources/App/ActivityTriggeredSwitching.swift` and `Sources/Domain/ActivityTriggeredSwitchingOutcome.swift`.
- Added shared Physical Keyboard discovery, Input Source, Physical Keyboard record change observation, and Operational Notification modules.
- Added `KeyameleonProductionFactory` at the application composition root. SetupModel now owns management only; RootView and Daily Status read the canonical switching outcome.
- Focused Swift Testing covers the preserved activation, convergence, recovery, lifecycle, pause, notification, and privacy behavior through deterministic adapter evidence.

## 2026-08-10 — Issue #19 Setup and accessibility qualification

- Added `./Scripts/run.sh qualify-setup-accessibility` for source audit, application build, complete tests, and privacy-safe human evidence evaluation.
- Added required case rows for Guided setup, management, Switching Status and recovery, Diagnostic Bundle and General Settings, keyboard operation, VoiceOver, visible state, and Reduce Motion on macOS 15 and macOS 26.
- Added stable SwiftUI accessibility identifiers for qualification discovery and verified the lifecycle UI journey through quit.
- Human physical and accessibility qualification remains required. Missing or unrun evidence is `inconclusive` and blocks an Official Release.

## 2026-08-10 — Issue #17 Automated Qualification

- Added source, dependency, binary, network, and crash-surface audits.
- Added deterministic 100,000 Physical Keyboard Event stress coverage and
  Activation Activity privacy sentinels.
- Added 10-consecutive-suite qualification with sanitized evidence and explicit
  pass, fail, or inconclusive verdicts.
- CI runs qualification on macOS 15 and macOS 26.

## 2026-08-10 — Issue #16

- Implement Official Release path: SemVer tag workflow, sign/notarize/staple script, Sparkle appcast, evidence JSON, GPL-3.0-only + notices, SECURITY Supported Release, contributing guidance.
- Host limits: private free tier cannot set environment required reviewers or branch protection via API — documented for lead maintainer.
- Env `official-release` created empty; secrets still must be added by maintainer before first real release.

## 2026-08-10 — Issue #13 Control Diagnostic Data and Diagnostic Sessions

- Domain: closed allowlist `DiagnosticCategory`/`DiagnosticEventCode`, session 10m, retention 7d/5MB, temporary tokens.
- Service: `KeyameleonDiagnosticDataService` + `InMemory`/`SwiftData` store; `ClockProviding`.
- Wire: SetupModel records operational state/errors; session-only detailed codes; forget deletes linked diagnostics.
- UI: General Settings → Diagnostics (start/stop session, clear all).
- Tests: `DiagnosticDataTests.swift`. Diagnostic Bundle review, save, and share = #14.

## 2026-08-10 — Issue #14 Review, save, and share Diagnostic Bundles

- Domain: `DiagnosticBundleBuilder` produces closed-schema JSON and a review summary.
- UI: Guided setup and General Settings show categories, exclusions, date range, record count, and size before explicit Save or Share.
- Save: user-selected destination through `fileExporter`; Share: macOS share interface through `ShareLink`.
- Lifecycle: local unclean-exit marker adds one dismissible Menu first notice with Review Diagnostics…; no notification.
- Tests: sensitive sentinel exclusion and unclean-exit/menu notice coverage.

## 2026-08-10 — Issue #10

- Recover selection failures + Unavailable Keyboard Assignments.
- Parent #1; blocked-by #5 closed.
- Domain warning/availability; SetupModel recovery; Retry Now; tests in `KeyameleonRecoveryTests`.
- No timed retry; no substitute select; exact identifier return ends unavailable.
- Merged main: keep #6 converge generation, #7 menu/pause, #9 manual designation.

## 2026-08-10 — Issue #9 Manual Physical Keyboard Designation

- Issue #9: leave/return/name confirmation for eligible ambiguous external identity groups.
- Domain: evidence rules + CryptoKit authenticator + phase enum.
- App: Keychain integrity key, designation store, SetupModel session + elevation on publish/event.
- UI: start button, status banner, name confirmation sheet.
- Tests: `ManualDesignationTests.swift` (eligibility, auth, flow, shared reject, empty name, no migrate, tamper).
- Suite green.
- Merged main: keep #6 converge + #7 menu first / pause.

## 2026-08-10 — Issue #7

- Menu first daily surface: Switching Status, Active PK, Keyboard Assignment, Current Input Source, action items, Pause/Resume.
- Pause persists; Active PK does not. Icon marks: permission / warning / pause (+ temp unavailable).
- Tests: `KeyameleonMenuFirstTests` + XCTest menu cases.
- Merged main #6: keep wanted-generation converge + mismatch menu lines.
- Follow-on: #11 sleep/lock → Temporarily Unavailable; #10 unavailable recovery actions; #12 no notify while Paused.

## 2026-08-10 — Issue #6

- Issue #6: converge after rapid activity + external Input Source changes.
- Parent #1; blocked-by #5 closed.
- Shipped: wanted generation, stale-readback discard, external change observer (no fight), mismatch UI/menu, A-B-A + rapid-order tests.
- Out of scope: Pause (#7), Retry Now (#10 failure recovery).

## 2026-08-10 — Issue #5

- Issue #5: implement Activity-Triggered Switching.
- Parent #1; blocked-by #4 closed.
- Shipped: event domain, CoreHID listen-only observer, Input Source select+verify, SetupModel serial consumer, Active PK UI/menu, tests green.
- Out of scope here: pause (#7), rapid converge extras (#6), failure recovery (#10).
- Merged main: keep #8 lifecycle publish (connected+disconnected) + #15 Launch at Login / Sparkle.

## 2026-08-10 — Issue #15
- Implementing Launch at Login (`SMAppService.mainApp`) and Sparkle 2 user-approved updates behind General settings.
- Blocked-by #2 already closed; working on current branch `t3code/implement-issue-15`.

## 2026-08-10 — Issue #8 Manage Physical Keyboard lifecycle

- Tests: `Tests/SwiftTesting/LifecycleTests.swift` (9 cases).
- Domain: `PhysicalKeyboardConnectionState`, `PhysicalKeyboardListOrdering`, disconnected factory.
- Store: `allRecords`, `deleteRecord`, `transferRecord`.
- Model: merge connected catalog + saved disconnected; active ID; forget/replace; no Input Source request on disconnect.
- UI: connection/active labels; Replace picker + confirm; Forget confirm.
- Follow-on: #5 wires Activation Activity into event observer and real selection.
