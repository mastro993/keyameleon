# Choices

## 2026-09-26 — Keyboard card actions collapse into a three-dot menu

Supersedes the actions-menu bullet under 2026-09-25. The card keeps one actions
menu and its contents shrink to three items.

### Defaults

- The menu trigger is a three-dot button placed after the Input Source button, so
  it follows the locale code the Input Source button shows.
- The menu holds three items: `Rename…`, `Forget` when the card has a Keyboard
  Assignment, and `Disable…` when the model offers a Physical Keyboard Exclusion.
- `Forget` clears the Keyboard Assignment. It leaves the saved Physical Keyboard
  Name and a Manual Physical Keyboard Designation in place, so the action is not
  destructive and takes no confirmation.
- `Disable…` keeps the Physical Keyboard Exclusion action, the `Not a Physical
  Keyboard?` confirmation, the `not-a-keyboard` identifier, and the Excluded
  Devices restore path.
- `KeyboardSettingsRow.hasActions` follows those three items only. A card that can
  offer none of them draws no trigger.
- `KeyboardSettingsRow` keeps `canReplace`, `canForget`, and
  `canStartManualDesignation`, and `KeyboardSettingsRowActions` keeps its
  `replace`, `forget`, and `startManualDesignation` closures. No card draws them,
  so Replace Saved Physical Keyboard, the destructive Forget, and Manual Physical
  Keyboard Designation have no Settings entry point while this stands. A card that
  can start Manual Physical Keyboard Designation still prints `Save it after it
  leaves and returns.` under the reason.

## 2026-09-25 — Keyboards settings pane gives each Physical Keyboard a card

One Physical Keyboard takes one card. The cards sit in a single list, so the set
stays scannable and the whole set fits one window.

### Seams

- `KeyameleonCardSurface` is the pane's card surface. It carries the one fill, the
  one radius, the one padding, and `isHighlighted` for the Active Physical
  Keyboard, so no call site invents its own.
- `KeyboardSettingsRow` derives one card's content from one Physical Keyboard: the
  status line, the optional warning and guidance lines, the Input Source control,
  and which actions the card offers. The list branches on nothing.
- `KeyboardSettingsRowView` draws that card and its actions menu.
- `PhysicalKeyboardNameSheet` edits the Physical Keyboard Name, opened from
  `Rename…` in the card's actions menu. The name is no longer an always-visible
  field.
- `KeyameleonKeyboardSettingsView` keeps the state and the sheets and dialogs,
  and no longer carries a `contentPadding` parameter that had one caller.

### Defaults

- The card fill is `Color.primary.opacity(0.06)`, and the Active Physical
  Keyboard's card uses `.tint.opacity(0.12)`.
- Card layout: a keyboard symbol, the Physical Keyboard Name, an `Active` marker,
  the connection state on its own line, a trailing Input Source button, and an
  actions menu. The Active Physical Keyboard's card takes the accent fill, and the
  `Active` marker stays beside the name so the state is never colour alone.
- One card is about 62 pt tall. Six Physical Keyboards fit one window, where the
  card this replaces needed about 235 pt each.
- List rows hide their separators and take 4 pt above and below, so the cards read
  as separate surfaces.
- The trailing Input Source button shows the assigned Input Source name and opens
  the searchable picker sheet. It reads `Assign Input Source…` when nothing is
  assigned, and `Input Source Unavailable` in orange when the assignment's Input
  Source is not on this Mac.
- Unsupported identifiers keep the connection state on the status line and report
  the reason on a second line, so a disconnected device still says so. A card that
  can start Manual Physical Keyboard Designation adds `Save it after it leaves and
  returns.` under the reason, which is where the card used to explain it.
- One actions menu per card holds `Rename…`, `Remove Assignment`, `Replace Saved
  Physical Keyboard…`, `Manual Physical Keyboard Designation…`, `Forget…`, and
  `Not a Keyboard…`. Items appear only when the model says the action is possible.
  `Not a Keyboard…` is an item in that menu rather than a button on a card, and
  its action and confirmation are unchanged.
- Renaming keeps the macOS product name visible as the sheet's field placeholder,
  so clearing the field is the documented way back to the product name.
- Excluded Devices stays its own section on the same card surface, with a footer,
  an `Include Again` button per row, and the `include-excluded-device-again`
  identifier.
- The pane keeps the `physical-keyboard-configuration`, `excluded-devices`, and
  `not-a-keyboard` identifiers and every confirmation dialog message.

## 2026-09-24 — Physical Keyboard Exclusion

Broad recognition stays as decided on 2026-09-23. A shortcut-equipped pointer is
still recognized as a Physical Keyboard; the person removes the device instead.

### Defaults

- One saved exclusion per physical input device, keyed by that device rather than
  by a CoreHID service: the Physical Keyboard Identity value when the device has
  one, and the vendor, product, and model facts when it has none. The identity
  anchor is dropped from the key, so services of one device agree.
- The built-in Physical Keyboard is never excludable. It takes the nil branch of
  the key derivation, not a runtime check, so a stale saved key cannot hide it.
- Exclusion is a filter, not a deletion. The saved Physical Keyboard Name, the
  Keyboard Assignment, and an authenticated Manual Physical Keyboard Designation
  survive an exclusion and come back on restore.
- A device excluded once stays excluded across disconnect, reconnect, restart,
  and the discovery catalogue reset that sleep, lock, and pause perform.
- The excluded device disappears from every surface that reads the Physical
  Keyboard list, produces no Activation Activity, opens no Switching Status
  warning, and cannot be retried: an exclusion clears the wanted Keyboard
  Assignment and the selection-failure warning that named it.
- The exclusion set lives in `UserDefaults` under
  `keyameleon.excludedPhysicalKeyboards` as JSON, next to the guided-setup
  decisions. `PhysicalKeyboardSchemaV1` keeps its two models and
  `PhysicalKeyboardMigrationPlan.stages` stays empty.
- Nothing removes an exclusion automatically. The Excluded Devices section in
  Settings is the only restore path, because every disconnect signal is also
  sleep, lock, and pause.
- Both surfaces offer the same action and the same confirmation: `Not a
  Keyboard…` on the Physical Keyboard card in guided setup and in Settings,
  followed by a `Not a Physical Keyboard?` dialog that names the device and says
  where to restore it. The action is not marked destructive: it deletes nothing.
- Onboarding shows no restore list. Settings ▸ Excluded Devices is the way back.

## 2026-09-23 — Operational Notifications removed

This supersedes the Operational Notification seams and defaults recorded under
Issue #12 and Issue #39, and the notification-authorization bullets under
Sparkle gentle reminders.

### Defaults

- Delete Operational Notifications end to end: the module, its episode and setup
  decision stores, the authorization seam, `NotificationSettingsOpening`, and the
  General Settings section that showed authorization state.
- Keyameleon requests no notification authorization and sends no user alert.
  Switching Status and the Menu bar panel stay the only surfaces that report a
  revoked Input Monitoring permission or an Unavailable Keyboard Assignment.
- Activity-Triggered Switching keeps its warning episodes. Only the alert
  delivery and the setup-offer gate that consumed them are gone, so
  `hasKeyboardAssignment` goes with them.
- Leftover `keyameleon.notifications.*` UserDefaults keys stay inert. No
  migration code is added to remove them.

## 2026-09-23 — Broad Physical Keyboard recognition

### Defaults

- Inspect every CoreHID device because keyboard and keypad collections can appear behind a pointer or vendor-defined primary usage.
- Recognize a Physical Keyboard when its primary or device usages include keyboard or keypad, or when it exposes a keyboard input element. Do not require LED output or reject a device because it also has pointer usage. This accepts some shortcut-equipped pointers in exchange for fewer missed keyboards and supersedes the 2026-08-23 pointer rule below.
- Keep recognition separate from assignment. External devices still need a stable, unambiguous hardware identity before they can receive a Keyboard Assignment.

## 2026-09-23 — Assignment pill connection borders

### Seams

- `MenuBarAssignmentPillStyle` — takes `MenuBarAssignmentList.ConnectionMark` instead of an `isActive` flag, so the outline follows the enum the row already publishes.

### Defaults

- Active pill is unchanged. Neutral fill, green connection mark, no outline, and the 2 pt accent stroke under increased contrast.
- Connected but inactive Physical Keyboard: 1 pt solid outline.
- Disconnected Physical Keyboard: the same outline, dashed `[4, 3]`, still at 0.55 content opacity.
- Outline colour is `Color.primary` at 0.25 opacity, and 0.5 at 1.5 pt under increased contrast, so it adapts to the appearance and no new colour enters the panel palette.

## 2026-09-22 — Local log files replace Diagnostic Data

### Defaults

- Delete Diagnostic Data end to end: the closed domain, SwiftData store, service,
  Diagnostic Session UI, bundle review window, and the `DiagnosticDataControlling`
  parameter on `KeyameleonSetupModel`, `ActivityTriggeredSwitching`,
  `KeyameleonGeneralSettingsModel`, and the composition root.
- One process-wide `KeyameleonLog` with four levels (`verbose`, `debug`,
  `warning`, `error`) and three categories (`app`, `switching`, `setup`). A call
  site emits one line and carries no logger, so nothing threads a destination
  through the models that used to take a diagnostic controller.
- The process is silent until `KeyameleonLog.start` installs a writer at launch.
  Hosted unit tests and SwiftUI previews never install one, so they cannot write
  to the user's Logs folder.
- `KeyameleonLogWriter.file` appends to `~/Library/Logs/Keyameleon/keyameleon.log`
  through one `O_APPEND` descriptor, rotates at 1 MiB into `keyameleon.<n>.log`,
  and keeps 5 rotated files. Every file operation is best effort: a missing folder,
  a full disk, or a lock must not interrupt switching.
- A line carries the timestamp, the level, the category, and the message. No
  Physical Keyboard Identity, no paths, no system error text, no Key Content.
  Keyboard-scoped lines name the Physical Keyboard.
- No line per Physical Keyboard Event. Activation Activity is logged only when it
  changes the Active Physical Keyboard, matching the deleted default recording
  mode that refused one record per event.
- Keep the Logs Folder row in the About page. Its Open button was already there
  and is unchanged.
- `Scripts/run.sh` audits the log writer and every log call site for Key Content,
  and fails when an audited path is missing instead of letting `grep` no-op.
- `ClockProviding`, `SystemClock`, and `ManualClock` were diagnostics-only and went
  with the feature. Log lines take the system time.

## 2026-09-22 — The Unclean Exit notice is removed

### Defaults

- Delete `UncleanExitState`, `UncleanExitPresentation`, and the Unclean Exit test
  file. Nothing tracks whether the previous process terminated normally, so the
  About page keeps no launch-condition notice and no launch opens About by itself.
- Remove the store from `KeyameleonApplicationDelegate` and
  `KeyameleonGeneralSettingsModel`, including the `hasPendingUncleanExitNotice`
  flag and its dismiss action.
- Two `UserDefaults` keys, `keyameleon.lifecycle.activeLaunch` and
  `keyameleon.lifecycle.pendingUncleanExitNotice`, are left behind on existing
  installs. They are inert and not worth a cleanup pass.
- A crash leaves no marker. The previous run never wrote its `Terminating` line,
  so the log file shows it, and the next launch appends to the same file.

## 2026-09-22 — Logging review round

### Defaults

- One file per type, following the project structure rule in `AGENTS.md`. The
  logging pipeline is now `KeyameleonLog`, `KeyameleonLogFile`,
  `KeyameleonLogWriter`, `KeyameleonLogLevel`, and `KeyameleonLogCategory`.
- `PhysicalKeyboardDiscoveryRecordChange` carries the Physical Keyboard Name.
  Discovery removes a keyboard from the catalog before it publishes a disconnect,
  so a subscriber that looked the name up read `name unknown` for every real
  disconnect.
- `KeyameleonLogWriter.appendOnlyFile` serves the single-instance exit path. A
  blocked second launch appends its one line and never rotates, so it cannot
  rename a file the running app holds open, and the line the user needs is still
  written.
- No log line per activation. The coalesced-selection line fired on every
  keypress of an assigned Physical Keyboard, which is normal typing, so `verbose`
  moved to external Input Source changes, which are rare.
- No cleanup ships for the retired `DiagnosticData.store` in Application Support.
  There are no production users, so no install can hold one.
- Connection logs name the Physical Keyboard the way the panel does. The saved
  record supplies the custom name, the catalog is the next source, and the
  discovery payload is the last resort.
- The writer collapses line breaks inside a message, so a Physical Keyboard Name
  from hardware or from the user cannot split one record into two.
- Rotation reads the size from the open descriptor rather than a cached count,
  because a blocked launch appends through its own writer. The cached count is
  gone instead of refreshed on a timer.
- Third round. The writer compares its descriptor's inode against the active
  path, so deleting or replacing the file from the Logs folder reopens it instead
  of appending to an unlinked file. The test that installs a process-wide writer
  runs on the main actor, which serializes it against every other test that
  installs one.

## 2026-09-21 — Release notes drop the custom Contributors section

### Defaults

- Remove the `### Contributors` avatar list from
  `Scripts/official-release-notes.sh`. The release page renders its own
  Contributors card from the body's user mentions, and the script's list
  duplicated it with square avatars (`avatars.githubusercontent.com/u/{id}`).
- Keep `@login` attribution on the change and Changelog lines. Those mentions
  are the card's input, and they carry the same logins the list did.
- Amend ADR 0006 and the `docs/release/official-release.md` verification
  checklist.

## 2026-08-27 — Remove automated UI tests

### Defaults

- Keep no `bundle.ui-testing` target. Verify behavior through Swift Testing and hosted XCTest seams.
- Remove UI-test-only launch arguments and persistence reset hooks from production code.
- `./Scripts/run.sh test` builds once, then runs the two hosted test bundles serially.

## 2026-08-23 — BLE keyboard identity and pointer HID

### Defaults

- A HID service is a Physical Keyboard only if it has keyboard usage and is not a pointer-first composite. Pointer-first composites (Logitech MX Master) advertise keyboard usage for extra buttons and have no keyboard LEDs. Typing keyboards that also expose a pointing collection (AULA-F75 knob) still have keyboard LEDs.
- BLE Physical Keyboards without a USB serial use the Bluetooth device address as the hardware identity. CoreHID unique IDs are software and churn on reconnect.
- Built-in identity and serial-number identity stay unchanged.

## 2026-08-17 — Release contributor avatars

### Defaults

- Keep the `### Contributors` heading (ADR 0006). Emit avatar images, not names
  or `@login` bullets: `![@login](https://avatars.githubusercontent.com/u/{id}?s=64&v=4)`.
- Resolve login+id from the associated PR user, then commit `.author`. Git name
  only when GitHub has no user.
- Grant Release workflow `pull-requests: read`. Explicit `permissions` dropped
  that scope → `/commits/{sha}/pulls` failed silent → v0.1.1 used git names.

## 2026-08-17 — CI hang-after-pass (grill Q1–Q3)

### Defaults

- Failure to fix: tests already passed, `xcodebuild` never exits (hang-after-pass). Not assertion flake. Not Required-gate optics. Not release `wait-for-ci`.
- Do not rewrite the test suites. Fix host / runner teardown.
- Done: job process exits when the last test finishes. Keep the 8-minute macOS job cap. No auto-retry. No silent 30-minute wait.

## 2026-08-17 — CI hang-after-pass (grill Q4–Q6)

### Defaults

- Cut live I/O in hosted XCTest on both sides: host skips live start; `ApplicationTests` inject fakes and `stop()`.
- After each `xcodebuild`, kill leftover Keyameleon from this run. Hygiene only — does not unblock a hung `xcodebuild`.
- Keep UI-first: `KeyameleonUITests` then product bundles.

## 2026-08-17 — CI hang-after-pass (grill Q7–Q10)

### Defaults

- Host skip via `startsApplicationSurfaceOnLaunch` (same shape as `startsUpdaterOnLaunch`). `override init` sets `false` when hosted unit tests. DI init defaults `true`. Skip switching, lifecycle observer, status item, guided-setup window.
- `run.sh` may kill only `Keyameleon` whose executable is under `DERIVED_DATA_PATH`.
- ADR for: hosted unit-test process must not start live CoreHID or the status item.
- No extra per-`xcodebuild` timeout. 8-minute job cap stays the backstop.

## 2026-08-17 — CI hang-after-pass (grill Q11–Q12)

### Defaults

- Hosted unit-test detect: `XCTestConfigurationFilePath` or `XCTestBundlePath`. UI tests omit both → stay live.
- `startsUpdaterOnLaunch = false` when hosted unit tests. Keep the updater flag separate from `startsApplicationSurfaceOnLaunch`.
- Test-only `KeyameleonApplicationDelegate` initializer defaults to `NoOpPhysicalKeyboardDiscoverer`, `NoOpPhysicalKeyboardEventObserver`, `NoOpInputSourceChangeObserver`, and `NoOpKeyameleonLifecycleObserver`.
- Local `./Scripts/run.sh test` green in ~61s after the change (180 Swift Testing + 11 XCTest). `xcodebuild` exited after XCTest; no hang-after-pass.

## 2026-08-16 — DMG-only Official Release distribution (grill)

### Defaults

- Supersede the ZIP-primary and GitHub-Releases-feed defaults from the 2026-08-14 Official Release workflow decision.
- Publish only `Keyameleon-<version>.dmg` as a Keyameleon-managed GitHub Release asset. GitHub-generated source links remain.
- Put `Keyameleon.app` and an Applications shortcut in the disk image.
- Do not publish a ZIP, custom source archive, `appcast.xml`, `release-evidence.json`, `CHANGELOG.md`, or changelog artifact on the release page.
- Publish the Sparkle appcast through GitHub Pages. Keep release evidence as a workflow artifact.
- Do not change `v0.1.0` or preserve its old GitHub Releases feed. Its installed copies may require a manual update.
- Release-note structure: categorized changes, separator, Changelog with full comparison and change list, Contributors.
- See ADR 0006.

## 2026-08-16 — Sparkle EdDSA secret shape

### Defaults

- `SPARKLE_PRIVATE_ED_KEY` is `generate_keys -x` output: 32-byte seed, one-line base64.
- Normalize (strip quotes / PEM / whitespace) and write a temp key file. Do not pipe `--ed-key-file -`.
- Fail in `normalize-sparkle-ed-key.py` if decode is not 32 or 64 bytes.

## 2026-08-16 — wait-for-ci query

### Defaults

- Poll check-runs for **Required CI gate**. Do not wait on skippable `Build and test`.
- Filter with standalone `jq --arg`. Do not pass `--arg` to `gh api --jq`.
- Release workflow grants `checks: read` so `GITHUB_TOKEN` can list check-runs.

## 2026-08-14 — Official Release workflow (grill)

### Defaults

- Start an Official Release only with `workflow_dispatch` on `main`. The workflow creates the annotated tag. Kill the tag-push trigger.
- Dispatch only when the chosen SHA is on `main`. `verify` waits for **Required CI gate** (45m). No feature-branch release.
- V1 has one Channel: Stable. Beta ignored. No in-app Channel picker. One Sparkle feed: `releases/latest/download/appcast.xml`.
- Tag stays `vMAJOR.MINOR.PATCH`. Dispatch `version` is SemVer core (`1.2.3`). Inject marketing and build numbers at Official Release build. Do not commit a version bump.
- Official Release is immutable. Fail if the tag already exists. Do not `--clobber` the zip.
- Homebrew descoped. No tap, no cask, no brew job. README stays zip primary, source-build secondary.
- Notes: `git log` since previous Official Release tag. Subjects only. No merge commits. No author names. No dispatch `notes`. First Official Release body starts with `Initial Official Release`. Empty range (new version, same commit): `No source changes since <previous tag>`.
- Same `main` SHA may receive a new Official Release version. Same version may not.
- Dispatch inputs: `version` only (SemVer core). `ref` is `main`.
- Environment `official-release` deployment branches: `main` (produce runs before the tag exists).
- Tag after artifacts. Notes from `official-release-notes.sh` before the new tag exists.
- Re-run of `produce` may finish a tag that has no GitHub Release. A new dispatch of the same version still fails if the tag exists.
- Reuse GitHub Environment `official-release`. Same secrets. Lead maintainer only until required reviewers exist.
- Local `SKIP_NOTARIZE=1` stays a non-Official path. No dispatch dry-run.
- Appcast is latest item only. No Sparkle deltas.

## 2026-08-14 — Issue #51 Complete accessible menu-bar panel

### Seams

- `MenuBarPanelAccessibility` — VoiceOver speech, keyboard focus order, overflow keyboard path. Tests live here.
- `MenuBarAssignmentList.Row` — one label (Physical Keyboard Name) + one value (Input Source, connection or Active, warning).
- `MenuBarPanelChrome` — Liquid Glass vs opaque (Reduce Transparency); rainbow vs high-contrast Active emphasis.
- `KeyameleonMenuBarPanelController` / `KeyameleonApplicationDelegate` — Escape and outside-click close the transient popover only.

### Defaults

- Keep shipped #50 surface: Keyboards + footer. Recovery and Pause/Resume stay in More. Cog remains Open Keyameleon (Quick Action).
- VoiceOver order: panel (Keyameleon + Switching Status), Keyboards heading, rows or empty state, Version, Open Keyameleon, More.
- Row speech: label = Physical Keyboard Name; value = `Italian, Active` / `US, Connected` / `French, Disconnected` plus warning once. Badge and warning symbol stay hidden.
- Version speech: label `Version`, value marketing number or `—`. Visible text stays `Keyameleon 0.1.0`.
- Keyboard Tab: assignment rows (read-only), then Open Keyameleon, then More. Pause/recovery/Settings/Quit via More menu.
- Open focuses a silent container (no ring). Tab moves to the first assignment or Open Keyameleon and shows the ring. Footer AppKit buttons become first responder only after Tab.
  - 2026-09-22: the panel also returns focus to the container on every key-window transition, so a row a pointer click focused cannot keep its ring across shows.
- Empty list: Tab starts at Open Keyameleon. Empty card is VoiceOver-only.
- Reduce Transparency → opaque `windowBackgroundColor` fill. No extra glass cards.
- Increased contrast → Active uses 2 pt accent stroke, not rainbow.
- Long Physical Keyboard Names wrap to 2 lines; Input Source stays 1 line. Full name stays in speech.
- Dismiss does not pause, resume, assign, or check again. Escape and outside-click use the same `performClose` path as `close()`. Tests cannot synthesize `NSEvent.keyEvent` (safety audit).

## 2026-08-14 — Release README audience and claims

### Defaults
- Public README is user-first: hook, install, use, privacy, then build / architecture / release / contribute.
- User is a person with multiple Physical Keyboards of different physical layouts. Not a language persona.
- No First-Key Guarantee in glossary, README, or UI. Activity-Triggered Switching is the named behavior.
- No user-persona glossary term. README uses prose only.
- Screenshot later at `assets/screenshot.png`: menu-bar icon + open panel, heading Keyboards, ≥2 assigned pills, one Active, Switching Status Ready.
- Install: Official Release zip primary. Source-build secondary. No Homebrew until a cask exists.
- Screenshot: placeholder + intended-shot description. No image file in this pass.
- Features: full user-visible surface, short bullets.
- Privacy: own README section.
- Maintainer block: build commands, short architecture, Official Release workflow + secrets table. Detail remains in `docs/release/official-release.md`.

## 2026-08-14 — Issue #50 Menu-bar Quick Actions, recovery banner, footer

### Seams

- `MenuBarPanelContent` — `MenuBarAssignmentList` plus footer. Overflow actions are typed here. Tests live here.
- `KeyameleonMenuBarPanelView` — renders keyboards and footer only.
- `MenuBarPanelContent.Action.closesPanel` — dismissal contract. View closes the popover before running a closing action.

### Defaults

- Panel body is Keyboards + footer. No Quick Actions row, recovery banner, or unclean-exit notice.
- Footer cog (`gearshape`) opens the main window (`Open Keyameleon`) and closes the panel. Incomplete setup continues there. No Continue Setup action.
- Overflow (ellipsis): Pause/Resume, recovery actions when Permission Required or Temporarily Unavailable offers them, Check for Updates…, Settings…, Quit Keyameleon. Diagnostics stay in the main window only.
- Pause / Resume and Check Again / Dismiss keep the panel open. Other overflow actions close it.
- Footer left: `Keyameleon <marketing>` from `CFBundleShortVersionString`. No build number. Blank or missing → `Keyameleon —`.
- Footer is its own full-width container. 1 pt `.separator` top border. List bottom pad 4, footer top pad 6.
- Footer right: two small `.circular` icon buttons. Cog a11y is `Open Keyameleon`. Ellipsis a11y is `More`.
- Overflow control is an AppKit `NSButton` + `NSMenu`. Do not add `sizeThatFits` — the safety audit treats `CGSize` as a forbidden `CGS*` surface. SwiftUI `Menu` inside the transient popover is not in the XCUITest tree.
- Click away from More cancels menu tracking and closes the panel. `NSMenu.popUp` would otherwise eat the click the transient popover needs.
- Panel order: Keyboards, footer.

## 2026-08-14 — Menu-bar assignment pills

### Seams
- `MenuBarAssignmentList.Row` — title (Physical Keyboard Name), subtitle (assigned Input Source), `isActive`. No trailing value.
- `MenuBarAssignmentPill` — white squircle pill; Active = 2 pt angular rainbow border + soft neutral badge at top right.
- `MenuBarAssignmentRows` — `LazyVStack`; viewport still `visibleRowLimit == 5`; no data cap.

### Defaults
- Squircle = `RoundedRectangle(cornerRadius: 16, style: .continuous)`.
- Theme-aware control background stays opaque for all pills. Active adds the rainbow border and a soft neutral `Active` badge. Text uses primary and secondary system styles.
- Disconnected content stays 0.5 opacity without dimming the adaptive background. Rows stay read-only.
- More than five pills: assignment area scrolls. Actions stay fixed.

## 2026-08-14 — Request Permission no-op

### Seams
- `NSInputMonitoringUsageDescription` in `Info.plist` / `project.yml` — required for `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` to show the Input Monitoring prompt.
- `KeyameleonSetupModel.requestPermission()` — Guided setup action: request listen permission, then open System Settings only if Switching Status stays Permission Required.
- `SystemListenPermissionProvider.requestListenPermission()` — activate the accessory app before `IOHIDRequestAccess`.

### Defaults
- Request Permission on Guided setup uses `SetupModel.requestPermission()`, not the switching module alone.
- Denied or already-denied requests open Privacy → Input Monitoring. Granted requests do not.
- Usage description names Activation Activity and Activity-Triggered Switching. No Key Content claim.

## 2026-08-14 — Issue #49 Assigned Physical Keyboards in menu-bar panel

### Seams

- `MenuBarAssignmentList` — pure presentation: assigned-only filter, Active/connected/disconnected order, row marks, Unavailable Keyboard Assignment copy, empty state, scroll boundary (`visibleRowLimit == 5`).
- `MenuBarPanelContent` — still owns remaining Menu first notices and actions; embeds one `MenuBarAssignmentList`.
- `MenuBarAssignmentSection` / `MenuBarAssignmentRowView` — render typed rows only. Rows are not buttons.

### Defaults

- Reuse `PhysicalKeyboardListOrdering` (Active, other connected, disconnected; alphabetical Physical Keyboard Name inside each group).
- A Keyboard Assignment is `assignmentState == .assigned`. Unassigned and unsupported Physical Keyboards stay out of the list.
- Resolved Input Source name when eligible catalog has it. Otherwise second line is `Unavailable Input Source` plus warning symbol and note `Unavailable Keyboard Assignment`.
- Heading is `Keyboards`. No app-name header. No assignment count.
- Empty state uses a theme-aware soft gray keyboard card: `No assigned keyboards` and `Open Keyameleon Settings to assign keyboards.` Open Settings stays in the existing action list.
- Distinct accessible marks: Active, Connected, Disconnected. Disconnected rows use 0.5 opacity.
- More than five rows: assignment area scrolls; actions stay outside the scroll view.
- Keep Switching Status, Temporarily Unavailable copy, unclean-exit notice, and current actions until #50 replaces them.
- When `outcome` has `.requestPermission`, panel shows **Request Permission** next to Switching Status. Action calls `SetupModel.requestPermission()`.
- Panel order: Keyboards first, then Switching Status / diagnostics notices, then actions.
- Drop Active Physical Keyboard / Keyboard Assignment / Current Input Source / mismatch / Needs action status lines. The assignment list replaces that dump.

## 2026-08-13 — Issue #48 Live Liquid Glass menu-bar panel

### Seams

- `KeyameleonMenuBarPanelController` — one AppKit module: show, toggle, and close one transient 320 pt `NSPopover` anchored to the existing `NSStatusItem` button. Refresh runs before presentation.
- `MenuBarPanelContent` — typed Menu first rows and actions. `KeyameleonMenuBarPanelView` renders that content on one native popover glass surface.
- `NSStatusItem` stays the durable menu-bar lifecycle. Icon marks and accessibility descriptions stay on the status-item button.

### Defaults

- Keep AppKit `NSStatusItem`. Do not switch to `MenuBarExtra`.
- Replace `NSMenu` with one `NSPopover` (`behavior = .transient`, `animates = false`) so click-outside and Escape close the panel. Close stays synchronous for tests and status-item toggle.
- Native Liquid Glass comes from the macOS 26 popover chrome. Do not wrap the panel or its sections in extra `glassEffect` / `NSGlassEffectView` cards.
- Opening the panel calls `ActivityTriggeredSwitching.checkAgain()` before show, then refreshes the status-item icon. That refreshes permission, observed Input Source, Keyboard Assignments, and Switching Status. Physical Keyboard list stays live through existing discovery observation.
- Status-item toggle ignores a show that would land within 250 ms of a transient close, so the same click cannot close and reopen the panel.
- Current Menu first rows and actions stay functional in the panel until #49/#50 replace that content.
- Cmd+Q and Settings shortcuts live on the panel actions. UI tests click panel buttons, not `statusItem.menuItems`.

## 2026-08-13 — Debug Run package resolve / legacy build locations

### Defaults
- Shared workspace settings use `BuildLocationStyle=UseAppPreferences` and `DerivedDataLocationStyle=Default`.
- `./Scripts/run.sh generate` rewrites those shared settings and changes user `UseTargetSettings` to `UseAppPreferences`.
- Sparkle stays a remote Swift package. No vendor, no exact-version pin for this fix.

## 2026-08-11 — Product validation and macOS 26 support

### Defaults
- This supersedes the qualification-process defaults recorded under Issues #17 and #19 below.
- Supported Release targets macOS 26.
- Pull requests run one focused product test suite with one fast safety audit.
- Monitor-only behavior and no saved Key Content remain hard failures.
- Repeated suites, fixed stress counts, human qualification matrices, qualification evidence files, and performance quotas are removed.

## 2026-08-11 — Issue #39 Activity-Triggered Switching module

### Seams

- `ActivityTriggeredSwitching` is the one concrete observable switching module. Its external surface is one immutable `ActivityTriggeredSwitchingOutcome` and seven product operations: start, stop, request permission, check again, pause, resume, and retry now.
- `PhysicalKeyboardDiscovery`, `InputSourceModule`, `PhysicalKeyboardRecordStoring`, and `OperationalNotifications` keep discovery, exact selection, record changes, and notification episodes local to their own deep modules.
- SetupModel owns Guided setup and Physical Keyboard management. RootView and Daily Status consume the switching outcome directly.

### Defaults

- Internal identifiers, wanted generations, selection request evidence, warning episode evidence, raw Physical Keyboard Events, and lifecycle adapter facts do not cross the product outcome.
- The production factory creates one shared discovery, Input Source, and Operational Notification module for the application lifetime.
- Focused tests use deterministic adapters and assert the product outcome plus internal adapter evidence.

## 2026-08-10 — Issue #19 Setup and accessibility qualification

### Seams under test
- `Scripts/qualify-setup-accessibility.py` — automated source audit, application build, complete test suite, and privacy-safe human evidence verdict.
- SwiftUI accessibility identifiers and grouped status values — stable discovery points for Guided setup and accessibility qualification.
- `KeyameleonLifecycleUITests` — first launch, close, reopen, menu actions, and quit lifecycle.

### Defaults
- Qualify every required setup and accessibility case on macOS 15 and macOS 26.
- Bind each report to the candidate source commit and keep source, build, and test gates separate from human evidence.
- Treat unavailable or unrun required cases as `inconclusive`; a candidate passes only when every gate passes.
- Keep `evidenceRef` and aggregate measurements only. Do not store Key Content, stable Physical Keyboard Identity or Input Source values, or participant identity.
- Keep Manual Physical Keyboard Designation outside the timed Guided setup journey.

## 2026-08-10 — Issue #12 Bounded operational notifications

### Seams under test
- `OperationalNotificationProviding` — alert authorization state, explicit alert request, and operational notification delivery.
- `OperationalNotificationEpisodeStoring` — persistent episode, sent, and recovery state.
- `NotificationSetupDecisionStoring` — one optional setup offer after the first Keyboard Assignment.
- `NotificationSettingsOpening` — General Settings access to notification settings.
- `KeyameleonSetupModel` — permission and Unavailable Keyboard Assignment episode boundaries.

### Defaults
- Request authorization only after an explicit Enable Operational Notifications action.
- Request `.alert` only. Do not request sound or icon badge access.
- Send only for revoked listen permission and a newly Unavailable Keyboard Assignment.
- Persist hashed episode tokens and sent state. Keep exact Physical Keyboard Identity and Input Source identifiers out of UserDefaults.
- Mark an episode sent before delivery. Recovery removes its sent state so a later recurrence can send once.
- Pause suppresses delivery. Notification denial never changes Activity-Triggered Switching.
- General Settings shows the current authorization state and opens System Settings without requesting again.

## 2026-08-10 — Issue #16 Official Release artifacts

### Seams under test
- `KeyameleonReleasePolicy` — Official Release tag shape (`vMAJOR.MINOR.PATCH`), artifact names, `GPL-3.0-only`, Supported Release = latest only.
- `KeyameleonReleaseEvidence` — JSON binding artifact SHA-256 + source tag/commit; reject bad tag/hash.

### Defaults
- Tag-only Official Release workflow (`v[0-9]+.[0-9]+.[0-9]+`); no branch push release.
- GitHub Environment `official-release` for the produce job; required reviewers documented (plan may block API enablement on private free tier).
- Secrets: Developer ID p12, notarytool API key, Sparkle EdDSA private+public — env/repo secrets only; `.gitignore` for local key material + `dist/`.
- Sparkle public key injected at Official Release build (`SUPublicEDKey`); debug builds may omit (existing #15 behavior).
- Artifacts on one GitHub Releases channel: zip, source tar.gz, `appcast.xml`, `release-evidence.json`.
- CI required checks documented for `main` protection.
- `SKIP_NOTARIZE=1` local path is not an Official Release.

## 2026-08-10 — Issue #13 Diagnostic Data + Diagnostic Sessions

### Seams under test
- **Domain pure** (`KeyameleonDiagnosticData`): closed allowlist categories/codes, session max 10m, retention 7d/5MB oldest-first, temporary Physical Keyboard tokens, estimated record size.
- **`DiagnosticDataControlling`**: start/stop session, auto-expire, record allowlisted operational/session events, clear all, delete by Physical Keyboard identity linkage, retention prune, read records.
- **`ClockProviding`**: time boundary for session + retention.
- **`KeyameleonSetupModel.forgetPhysicalKeyboard`**: also deletes Diagnostic Data linked to that Physical Keyboard.
- **`KeyameleonGeneralSettingsModel`**: Diagnostics section (session + clear).

### Defaults
- Typed API only — no free-form String payload path into Diagnostic Data.
- Default recording: operational errors + state changes. Not one record per Physical Keyboard Event.
- Diagnostic Session unlocks detailed allowlisted categories (observation order, Input Source selection result, relative timing) still without Key Content or identity values.
- Physical Keyboard linkage: SHA-256 of identity key → temporary UUID token (no exact identity/serial in Diagnostic Data store). Records store token only.
- Size retention uses fixed `estimatedBytesPerRecord` (closed schema; not on-disk measurement).
- Separate SwiftData container for Diagnostic Data (no PK schema migration risk).
- Session auto-stop checked on access/record + MainActor timer while active.
- Forget confirmation copy includes Diagnostic Data removal.
- UI: General Settings → Diagnostics (start/stop session, clear all). Diagnostic Bundle review, save, and share is #14.

## 2026-08-10 — Issue #14 Review, save, and share Diagnostic Bundles

### Seams under test
- **`DiagnosticBundleBuilder`**: stable JSON export from the closed Diagnostic Data schema, with category, date range, count, size, and exclusion summary.
- **`KeyameleonDiagnosticBundleReviewView`**: Guided setup and General Settings review surface with explicit Save and Share actions.
- **`UserDefaultsUncleanExitStateStore`**: local active-launch marker and one dismissible Menu first notice after an unclean exit.

### Defaults
- Save uses SwiftUI `fileExporter` so the user selects the destination.
- Share uses SwiftUI `ShareLink` and the macOS share interface.
- Bundle records contain only closed allowlist fields and temporary Physical Keyboard tokens; no Physical Keyboard Identity, Key Content, crash report, or path data.
- The unclean-exit notice is local, sends no notification, and clears only after Review Diagnostics… or Dismiss Diagnostics Notice.
- Controlled sensitive sentinels are tested as absent from generated bundles.

## 2026-08-10 — Issue #10 selection failure + Unavailable Keyboard Assignment seams

- **Domain pure**: `SwitchingWarning`, `SwitchingFailureCategory`, `SwitchingRecoveryAction`, `WantedKeyboardAssignment`, `KeyboardAssignmentAvailability` (exact identifier only).
- **Recovery coordinator** on `KeyameleonSetupModel`: one warning per active cause, `retryNow()`, skip select for unavailable, reevaluate on Input Source refresh.
- **Converge integration**: keep wanted generation + generation-gated readback from #6; `WantedKeyboardAssignment` adds Physical Keyboard ID for Retry Now.
- **InputSourceSelecting** unchanged: restore prior Input Source on exact readback mismatch.

Defaults:

- Selection failure cause is singular (current wanted). Newer assigned Activation Activity replaces wanted + may reselect.
- Unavailable cause is per Physical Keyboard Record ID. Saved assignment stays; no substitute select.
- Exact eligible-identifier return clears unavailable only. No timed retry loop.
- `warningEpisodeCount` increments only when a new cause becomes active.
- UI: plain category + recovery copy + **Retry Now** for selection failure; Change/Remove already on keyboard row.

## 2026-08-10 — Issue #9 Manual Physical Keyboard Designation

### Seams under test
- `ManualPhysicalKeyboardDesignationEvidenceRules` — offer eligibility + return accept + confirmed name.
- `ManualPhysicalKeyboardDesignationAuthenticator` — CryptoKit HMAC over identityKey/productName/confirmedName only (no Key Content).
- `InstallationIntegrityKeyProviding` — Keychain-backed SymmetricKey (in-memory for tests).
- `ManualPhysicalKeyboardDesignationStoring` — authenticated evidence persistence (SwiftData + in-memory).
- `KeyameleonSetupModel` session: start → leave → return → confirm name; other Physical Keyboards stay assignable.

### Defaults
- Eligible only: external, identity-based, `.unsupported(.ambiguousIdentity)`. Missing/unstable/shared never offered.
- Ambiguous multi-interface return still valid (approved exceptional case). Shared/unstable/missing return not accepted.
- Save name + designation evidence only; no Keyboard Assignment from the flow.
- Integrity key: Keychain generic password, service `dev.fedemas.keyameleon.installation-integrity`.
- Designation model lives in `PhysicalKeyboardSchemaV1` container (additive model). Tampered HMAC → stay unsupported.
- Identity change: no auto migrate/delete of designation or records.
- Forget deletes designation for that identityKey.

## 2026-08-10 — Issue #7 Menu first + pause

- **Pause persist**: `SetupDecisionStoring.isActivityTriggeredSwitchingPaused` / UserDefaults key `keyameleon.activityTriggeredSwitching.paused`.
- **Status resolve**: pure `SwitchingStatus.resolve` priority Permission Required → Temporarily Unavailable → Paused → Ready.
- **Discovery vs observe**: Paused keeps Physical Keyboard discovery for management; stops Key Content observation + Input Source requests (`allowsPhysicalKeyboardDiscovery` vs `allowsActivityTriggeredSwitching`).
- **Temp unavailable**: flag slot on SetupModel for #11; no sleep/lock wiring in #7.
- **Menu bar icon**: SF Symbol shapes per `MenuBarIconMark` (not color-only). Item warning only when Ready.
- **Menu first action items**: unassigned + Unavailable Keyboard Assignment lines; incomplete setup still uses Continue Setup….
- **Resume**: clear pause → recheck listen permission → start observation only if Ready.

## 2026-08-10

### Issue #6 Converge after rapid activity and external changes

Seams under test:
- `KeyameleonSetupModel.handlePhysicalKeyboardEvent` — serial activity consumer (observation order).
- Wanted Keyboard Assignment generation on `KeyameleonSetupModel` — bump per select need; discard stale readback.
- `InputSourceChangeObserving` — external Input Source changes (manual / shortcut / other apps).
- `activeInputSourceMismatch` presentation — current vs assigned when they differ.
- `KeyameleonAppMetadata` restore copy.

Defaults:
- Sync TIS select still generation-gated so nested/reentrant activity cannot apply stale verify.
- External change: update observed current, clear verified when current ≠ verified, never select.
- Coalesce only when wanted + verified + current all match the assignment.
- UI/Menu first show current + assigned names + restore explanation only on mismatch for Active assigned keyboard.
- System observer: `DistributedNotificationCenter` + `kTISNotifySelectedKeyboardInputSourceChanged`.

### Issue #5 Activity-Triggered Switching seams

- **Activation Activity classification** (domain pure): `PhysicalKeyboardEventKind` press/repeat/release; release not Activation Activity.
- **Switching coordinator** via `KeyameleonSetupModel`: Active Physical Keyboard, request exact Keyboard Assignment, exact identifier readback.
- **Input Source select/verify** protocol: `InputSourceSelecting` (TIS boundary).
- **Event observe** protocol: `PhysicalKeyboardEventObserving` (CoreHID listen-only; no seize).
- **Catalog**: serviceID → Physical Keyboard for attribution.

Defaults:

- Coalesce select when wanted assignment already verified active (story 57 minimal).
- Failures leave input unchanged (restore prior Input Source on readback mismatch); no toast (#5); no retry loop.
- Active Physical Keyboard not persisted across restart.
- Lifecycle list merge from #8 stays authoritative in `publishPhysicalKeyboards`.

## 2026-08-10 — Issue #15 Launch at Login + updates

### Seams under test
- `LaunchAtLoginControlling` — enable/disable Launch at Login; `ServiceManagement` adapter uses `SMAppService.mainApp` (no login helper).
- `UpdateChecking` — start on launch + manual check; Sparkle adapter only.
- `KeyameleonUpdatePolicy` — pure constants for 24h interval, no auto-install, no system profile, no Keyameleon-generated identifiers.
- `KeyameleonGeneralSettingsModel` — General settings presentation over those seams.
- `KeyameleonAppMetadata` — user-visible General / Launch at Login / update strings.

### Defaults
- Sparkle Info.plist: automatic checks on, interval 86400s, automatic download/install off, automatic-update option disallowed, system profiling off.
- Feed URL: `https://github.com/mastro993/Keyameleon/releases/latest/download/appcast.xml` (Official Release issue owns appcast + EdDSA key).
- `SUPublicEDKey` omitted until release tooling supplies it; updater start failures stay non-fatal so debug builds still launch (explicit exception to fail-loud until Official Release keys exist).
- Critical-update warning: Sparkle standard user driver + General settings copy; `SUAllowsAutomaticUpdates=false` so critical never auto-installs.
- General Settings: Launch at Login toggle + Check for Updates… + short critical-update warning copy.
- Menu first: Settings… and Check for Updates… entries.
- Dropped `SYMROOT` (blocks SPM); `Scripts/run.sh` uses `-derivedDataPath build`.

## 2026-08-10 — Issue #8 Physical Keyboard lifecycle

- **Seams under test**: `PhysicalKeyboardRecordStoring` and `KeyameleonSetupModel` (application-service seam from parent #1). Catalog unit rules stay in domain tests.
- **Active Physical Keyboard**: in-memory only on `KeyameleonSetupModel`; not persisted across app restart. `noteActivationActivity` remains a test/manual seam; real switching uses `handlePhysicalKeyboardEvent`. Lifecycle slice never increments Input Source selection requests.
- **Disconnected list merge**: saved SwiftData records whose identity is not in the live catalog publish as `connectionState == .disconnected`. Catalog still drops disconnected HID services.
- **Replace**: explicit model API + confirmation UI; candidates are disconnected saved identity-based records only.
- **Forget**: deletes store record only. Connected hardware republishes as new unassigned from catalog; disconnected vanishes.
- **Schema**: keep PhysicalKeyboardSchemaV1. No new columns; disconnected rows reuse productName + assignment + identityKey. Transport for disconnected-only rows is `.other`.

## 2026-08-11 — Issue #41 Local presentation ownership

### Seams under test
- AppKit menu and icon presentation — menu titles, order, accessibility values, status symbols, and unclean-exit actions.
- SwiftUI presentation owners — Guided setup, Physical Keyboard configuration, General Settings, and Diagnostic Bundle review copy.
- Typed domain and model facts — switching conditions, Physical Keyboard conditions, Input Source mismatches, and Launch at Login errors.
- Independent UI-test contracts — bundle identity, accessibility identifiers, launch arguments, and externally visible copy.

### Defaults
- `KeyameleonAppMetadata` is deleted. No replacement registry, copy enum, or string-only file is added.
- Each implementation owns its user-visible copy and private formatters. Duplicate copy remains local when presentation owners happen to share text.
- Domain and model interfaces expose typed facts or domain data. Physical Keyboard Names, Input Source names, persisted codes, and Diagnostic Bundle exclusion labels remain domain-owned.
- `SwitchingStatus.rawValue` values stay unchanged because Diagnostic Data persists them.
- Runtime application identity comes from the application bundle. Published product and artifact identity remains deterministic in `KeyameleonReleasePolicy`.
- UI tests keep independent expected literals. Production accessibility identifiers and launch arguments remain unchanged.
- Earlier choices that named `KeyameleonAppMetadata` are superseded for ownership only; their external values and behavior remain unchanged.

## 2026-09-21 — Sparkle gentle reminders

### Defaults
- `SparkleUpdateChecker` conforms to `SPUStandardUserDriverDelegate` and returns `supportsGentleScheduledUpdateReminders`. Sparkle logs its background-app warning only when that property is missing or false.
- Sparkle keeps showing its own update alert. `standardUserDriverShouldHandleShowingScheduledUpdate` stays unimplemented.
- A scheduled update makes the app findable. Activation policy becomes `.regular` with Dock badge `1`. User attention clears the badge. The end of the update session clears the badge and restores `.accessory`. Steady state stays menu-bar-only.
- A user-initiated check changes nothing. The user already asked for the update.
- No update notification and no new authorization request. Notification authorization stays owned by Guided setup and General Settings, which ask with `[.alert]` after an explicit user action.
- Update state stays out of `OperationalNotification` and `MenuBarIconMark`.
- `updater(_:willScheduleUpdateCheckAfterDelay:)` stays unimplemented. Sparkle's sample uses that hook to request notification permission, which would bypass the setup offer gate.

## 2026-09-22 — Release-type dispatch and committed app version

### Defaults

- Release dispatch accepts one choice: `patch`, `minor`, or `major`; `patch` is the default.
- Latest valid Official Release tag reachable from `main` is the version authority. Checked-in `MARKETING_VERSION` starts aligned with that release and advances with each release commit.
- Release job commits `MARKETING_VERSION` plus the generated Xcode project as `chore(release): X.Y.Z`, tests that commit, then pushes it directly to `main`.
- `CURRENT_PROJECT_VERSION` remains unchanged in source. Official Release builds continue deriving both bundle values from the release tag.
- Main ruleset grants deploy keys `always` bypass because personal repositories cannot add GitHub's first-party Actions app as a bypass actor. One repository-scoped write key lives only in the `official-release` environment; the bump job otherwise has read-only token permissions.
- Release tag, evidence, signed DMG, and GitHub Release all point to the bump commit. Release notes stop at its parent so the mechanical bump is omitted.
- This supersedes the 2026-08-14 exact-version input, no-version-commit, and same-SHA-release defaults.


## 2026-09-22 — Menu-bar panel starts each show on the silent container

### Defaults

- `KeyameleonMenuBarPanelView` returns focus to the silent container whenever one of the app's windows becomes key, which is the moment the popover is shown.
- The popover reuses one content view across shows, so `onAppear` and `onDisappear` do not run per show. The key transition is the only per-show signal the view gets.
- Keyboard focus order, the silent container, and `focusEffectDisabled(focusedTarget == .container)` stay as shipped in #51.
