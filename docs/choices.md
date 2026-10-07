# Choices

## 2026-10-07 — Homebrew cask in a shared tap

### Defaults

- One public tap for every product: `mastro993/homebrew-tap`. Install with `brew install --cask mastro993/tap/keyameleon`.
- The cask downloads the same Official Release DMG. No extra release asset.
- `auto_updates true`: Sparkle stays the updater. `brew upgrade` upgrades the cask only when the installed app's `CFBundleShortVersionString` is older than the tap version.
- `publish` updates the cask only after the GitHub Release, feed, and evidence are verified.
- The tap push uses its own write deploy key (`HOMEBREW_TAP_DEPLOY_KEY`), scoped to the tap. Each product gets its own key on the tap.
- Official `homebrew/cask` waits until the repository passes Homebrew's notability audit.

## 2026-10-07 — One native spacing policy across the Settings panes

General, Keyboards, and About share one grouped-`Form` spacing policy: platform
content margins, platform row insets, and no per-pane outer padding. The
Keyboards pane no longer wraps its list in `Theme.Metrics.panePadding`, and its
duplicated scroll content-margin override is removed. On macOS 26 grouped forms
`listRowInsets` stays inert, but a `contentMargins` override does move the
margin, so that override only ever knocked Keyboards out of line with General and
About; all three panes now use the platform grouped-`Form` defaults. The empty
and persistence-failure Keyboards states use a 20 pt vertical and 30 pt
horizontal inset, matching the populated list's header top edge, and a
persistence failure still hides only the empty state.

The Settings window keeps its 840 × 560 minimum. The window controller already
sets `contentMinSize`; `SettingsView` now also enforces the same
`Theme.Metrics.settingsWindowMinimumHeight`, so the SwiftUI content cannot lay
out shorter than the window's own minimum. This entry refines the spacing in the
2026-10-07 standard-controls entry.

## 2026-10-07 — Standard SwiftUI controls inside the branded windows

Settings and Guided setup retain their branded sidebar shells, colors, identity,
and window minimums. Settings navigation uses `List(selection:)` for native
selection, focus, and accessibility while keeping the existing blue selected row.
The Guided setup sidebar and informational progress indicator remain unchanged.

General and About use grouped `Form` and `Section`; About values use
`LabeledContent`. Launch at login owns its title and explanation in the native
`Toggle` label. Folder paths remain selectable, read-only text with the existing
Finder action. The About identity and scrolling creator credit remain outside
the information rows.

Keyboard containers use native sections and scrolling rather than `InsetGroup`
and manually drawn separators. Guided setup's Keyboards stage has one scrolling
region containing progress, explanation, keyboard rows, and its note; the footer
stays reachable below it. Shared keyboard row reconciliation, actions menus,
rename sheets, and persistence behavior are unchanged. A grouped `Form` draws a
menu `Picker` borderless and sized to its value, so the Input Source control is a
bordered `Menu` hosting the inline native `Picker`; it fills one fixed 176-point
column, so every row's control is the same width in Guided setup and Settings.
Settings uses `ContentUnavailableView` for no keyboards only when saved data is
available; a persistence failure still shows Retry without a misleading empty
state.

Sidebar rows, folder paths, and the setup footer use minimum heights so taller
content can grow. Link cursors use SwiftUI `pointerStyle`; menu assignment springs
are disabled under Reduce Motion. Native menu tracking, notice buttons, and the
permission guide's actual application-file drag payload remain in AppKit.
Unused alternative keyboard selectors and the unused image-only button helper
are removed. This entry supersedes the custom group and navigation details of
the 2026-10-05 Settings entry.

## 2026-10-06 — Menu keyboard pills are single-line with a locale badge

The menu panel's keyboard pills are one 34 pt line: connection mark, the
Physical Keyboard Name, an optional warning triangle, and the assigned Input
Source's locale code. The pill's `@ScaledMetric` frame and the five-row
scroller share `Theme.Menu.rowHeight` as a row minimum, not a fixed row height:
a row with taller content clips at the viewport instead of growing it.

### Defaults

- The title is the Physical Keyboard Name, custom name when set and the product
  name otherwise, in one tail-truncated line. This supersedes the 2026-10-05
  subtitle sentence and the 2026-09-23 `subtitle` entry.
- The locale code renders inline in the pill: a filled `Color.primary`
  rectangle with `.background` text at `Theme.Typography.chip`, at least 24 × 16
  with radius 4 and a 4 pt horizontal inset, growing for a code longer than two
  letters instead of truncating.
- `MenuBarAssignmentList.Row` drops `subtitle` and the stored
  `showsWarningSymbol`, which is now computed from `warningNote`. The VoiceOver
  label and value are unchanged.
- A disconnected pill takes one 0.65 opacity layer across the mark, title, and
  badge, raised to 0.8 under Increase Contrast. The warning triangle stays
  undimmed, and no second mute or opacity layer stacks on those elements.
- `Theme.Menu` drops the now-unused `muted`, `detailGap`, `badgeBorder`, and
  `strongBadgeBorder` tokens, and `Theme.Typography.chip` is `caption2` bold.
- No Settings, onboarding, dependency, or private API change. Native pixel parity
  is not claimed; the reference capture did not show the open menu.

## 2026-10-06 — About lives only in Settings

The status menu and application menu omit About Keyameleon. The independent
compact About window and its Licenses and Notices button are removed. Settings →
About remains the home for app identity, credits, bundled licenses, and updates.
Check for Updates… remains a native status-menu row directly below Settings.
Earlier references to the compact window describe superseded behavior.

## 2026-10-05 — Settings is rebuilt from the Pencil design

The Settings window is now the Pencil `Settings / General`, `Settings /
Keyboards`, `Settings / About`, and `Settings / Keyboards / Empty` designs. It
is the only Settings presentation: the old split view, form panes, and keyboard
cards are deleted. Guided setup and Settings draw from one theme, one inset
group, and one Physical Keyboard row.

### Seams

- `Theme` — the design's colors and type roles plus the metrics Settings sizes
  itself with: an 840 × 560 content minimum, a 220 pt sidebar with a 24 pt top
  inset, a 24/30 pane inset, 20 pt between a pane's blocks, radius 16 for the
  keyboard group, radius 10 for information rows, and radius 6 for the navigation
  item. `Theme.Typography` spells the design's roles with the semantic styles
  their sizes match: `type-headline` medium for a section title, `type-body`
  medium for a row title and the selected sidebar item, `type-body` semibold for
  the sidebar mark, `type-callout`, `type-subheadline`, and `type-title-2` medium
  for the About app name. Settings packs its keyboard rows at 16 pt while Guided
  setup keeps the design's 18/22, and information rows take a 16 pt inset and the
  design's 39 pt height. `OnboardingPalette` names the same color tokens for
  Guided setup, so neither flow invents a color or a length.
- `InsetGroup` and `keyameleonGroupSeparator(_:)` — the rounded group
  and its hairline, drawn by the Keyboards list, Guided setup, and About.
- `PhysicalKeyboardRows` and `PhysicalKeyboardRowView` — one reconciled list and
  one row shared by Guided setup and Settings. `reconcile(with:)` reads the setup
  model, so both flows keep row identity, ordering, and ignored rows the same way.
  The built-in Physical Keyboard stays first, including when discovered after
  other rows. External and ignored rows retain their relative order and identity.
  Editable and read-only Input Source pickers show `Unassigned` for no assignment.
- `SettingsView` — the sidebar and pane shell, with
  `SettingsSidebar`, `GeneralSettingsPane`,
  `KeyboardSettingsPane`, and `AboutSettingsPane`.
- `BundledLicense` — the bundled `LICENSE.txt` and
  `Sparkle-LICENSE.txt` the About pane opens for offline reading.
- `GeneralSettingsModel` is `@MainActor @Observable`. Settings and its About
  pane read it without a property wrapper.

### Defaults

- The window hides its title and makes the content full size, so the design's
  sidebar sits under the traffic lights. The sidebar shows the keycap mark from
  `Keycap` — the design's crop of the official logo, not the app icon,
  which stays on the About pane. Resizing keeps the 840 × 560 content minimum.
  General stays the default pane, reopening keeps the current pane, and the
  menu-bar dismissal, cached controller, and setup-to-Settings handoff are
  unchanged.
- Keyboards lists included and ignored Physical Keyboards in one group: name and
  connection status, the native Input Source picker, and one actions menu holding
  `Rename…` and then `Ignore` or `Stop ignoring`. Rename keeps its sheet and
  product-name placeholder. Ignore and Stop ignoring write through the model
  immediately and keep the row in place; an ignored row mutes its name, connection
  status, and Input Source text, keeping its saved Input Source with the native
  picker disabled. Missing or ambiguous saved records show `Unassigned` in the
  same disabled picker. The built-in keyboard reserves the menu column without
  offering actions. Unsupported identities keep their reason, and a persistence
  error disables the picker and the menu.
- The Keyboards empty state is the design's keyboard symbol, `No keyboards
  detected`, and its connection guidance. While either store is unreadable —
  `SetupModel.hasPersistenceFailure` covers the record and switching stores — the
  pane shows no empty state and keeps the persistence notice and Retry instead.
- About shows the app icon, name, and tagline, then information rows for version,
  source code, app data folder, logs folder, license, and updates, then the
  Sparkle acknowledgement, and the creator credit as the last content block, so
  it scrolls with the pane rather than pinning to the window. Folder rows show a selectable
  path with Open in Finder. License rows open the bundled texts and are disabled
  when the build does not carry them. Updates is disabled while Sparkle cannot
  check. The version is read from the bundle and shows the build number.
- Settings offers no Forget, Replace Saved Physical Keyboard, or Manual Physical
  Keyboard Designation entry point. Those model seams and their tests remain.

### Superseded

- 2026-09-25 and 2026-09-26: `KeyboardSettingsRow`, `KeyboardSettingsRowView`,
  and `KeyameleonCardSurface` are deleted, and their tests with them.
- 2026-09-27: the separate Settings Excluded Devices section is gone. Ignored
  keyboards stay in the list and offer `Stop ignoring`.
- 2026-10-04: Settings no longer keeps its own confirmation path; Ignore and
  Stop ignoring save immediately, exactly as Guided setup does.
- 2026-09-26 ellipsis rule: this design's copy uses the ellipsis character in
  `Rename…` and `Check for Updates…`, as Guided setup already shipped it.

## 2026-10-04 — Guided setup keyboard rows match the Pencil design

- The Keyboards step uses a short explanation above an unheaded list. An
  external keyboard has a trailing actions menu after its native Input Source
  picker: Rename… when its identity is safe, then Ignore. Ignored rows offer
  Rename… for an exact saved record and Stop ignoring. Missing or ambiguous
  saved records offer only Stop ignoring. The built-in keyboard reserves the
  menu space without offering actions. Settings keeps its existing confirmation path.
- Ignored rows retain their position, name, product, and disabled saved Input
  Source. Rename uses the existing saved-record transaction and leaves the
  exclusion and assignment intact. The model checks the exact record and
  exclusion again when saving; a failed persistence operation retains its
  retry command. The row collection matches an anchored record first, then
  a unique exclusion group. Multiple matches without an anchor remain
  ambiguous.
- An included keyboard subtitle shows `Connected` or `Disconnected`. It prefixes
  the original product name and ` - ` only when a custom name exists. Ignored
  rows append ` (Ignored)` to that connection status while using current hardware
  connection state outside the switching catalog; missing or ambiguous saved
  records show the status without a product prefix.
  Unsupported details remain available on the trailing `Unsupported` text.
- The three onboarding stages use semantic macOS type styles, and the Ready
  illustration uses the updated light and dark Pencil artwork.
- This supersedes the onboarding control and ignored assignment details in the
  2026-09-27 entry below.

## 2026-09-30 — Store Physical Keyboard data in the Keyameleon folder

- The production SwiftData store lives at
  `~/Library/Application Support/Keyameleon/default.store`. Settings > About
  derives App Data Folder from that same configuration and opens its parent.
- Before opening the new store, copy the legacy `Application Support/default.store`
  with SQLite's backup API. The snapshot includes committed WAL transactions and
  preserves names, assignments, designations, authentication tags, and store metadata.
  The current schema has no external-storage attributes.
- Copy into `.store-migration` inside the destination folder, close the standalone
  database, then publish it with a same-volume move. A failed or interrupted copy
  is retried on the next launch. Keep the legacy store and its sidecars untouched.
  An existing destination always wins; never replace it with stale legacy data.
- Migration failures stop container creation rather than opening an empty store.
  Hosted tests and Xcode previews use an in-memory container; migration tests use
  disposable directories.
- To back up Physical Keyboard Names, Keyboard Assignments, and Manual Physical
  Keyboard Designations, quit Keyameleon, then copy the store and any matching
  `-wal` and `-shm` sidecars together from App Data Folder. Setup decisions and
  Physical Keyboard Exclusions remain in UserDefaults; the integrity key remains
  in Keychain. Copying this folder alone is not a complete application backup.

## 2026-09-28 — Resume unfinished Guided setup from the menu bar

- While Guided setup is incomplete, the menu-bar action list offers `Continue Guided Setup` in every Switching Status. It stays available even when a higher-priority notice is showing.
- The action uses the existing `continueSetup` presentation path. The saved permission or assignment step remains in `SetupModel`; reopening only advances permission when Input Monitoring has since been granted.
- Completing setup removes the action and unfinished notice. Reopening a second app instance remains silent.
- This supersedes the old `No Continue Setup action` menu decision below.

## 2026-09-26 — Keyboard card actions collapse into a three-dot menu

Supersedes the actions-menu bullet under 2026-09-25. The card keeps one actions
menu and its contents shrink to three items.

### Defaults

- The menu trigger is a three-dot button placed after the Input Source button, so
  it follows the locale code the Input Source button shows.
- The menu holds three items: `Rename`, `Forget` when the model allows forgetting
  the Physical Keyboard, and `Disable` when the model offers a Physical Keyboard
  Exclusion.
- No item in this menu uses the ellipsis character. A menu item that opens a
  sheet or a confirmation takes the bare verb, so the item reads `Rename`, not
  `Rename…`. Keyameleon copy must not use the ellipsis character at all. These
  sites still do and are outstanding: `Assign Input Source…` in
  `KeyboardSettingsRow`, `Check for
  Updates…` in `AboutSettingsView`, `Waiting…` in
  `OnboardingView`, and the `…` truncation marker in `LogFile`.
- `Forget` is the Physical Keyboard forget, unchanged: it removes the saved
  Physical Keyboard Name, Keyboard Assignment, and Manual Physical Keyboard
  Designation, keeps `role: .destructive`, and is followed by the
  `Forget Physical Keyboard?` confirmation. Nothing clears a Keyboard Assignment
  on its own; changing the Input Source is the way to act on an assignment.
- `Disable` keeps the Physical Keyboard Exclusion action, the `Not a Physical
  Keyboard?` confirmation, the `not-a-keyboard` identifier, and the Excluded
  Devices restore path.
- `KeyboardSettingsRow.hasActions` follows those three items only. A card that can
  offer none of them draws no trigger.
- `KeyboardSettingsRow` keeps `canReplace` and `canStartManualDesignation`, and
  `KeyboardSettingsRowActions` keeps its `replace` and `startManualDesignation`
  closures. No card draws them, so Replace Saved Physical Keyboard and Manual
  Physical Keyboard Designation have no Settings entry point while this stands. A
  card that can start Manual Physical Keyboard Designation still prints `Save it
  after it leaves and returns.` under the reason.

## 2026-09-27 — Onboarding keeps excluded keyboards visible

This supersedes the onboarding restore details in the 2026-09-24 exclusion entry.

### Defaults

- An excluded keyboard stays in its onboarding row, marked `Excluded`, with an
  `Include Again` action in place of assignment controls.
- Existing row identities and positions stay stable through exclude and restore
  during the current onboarding session. Newly discovered keyboards append in
  the existing Physical Keyboard order. Since 2026-10-06, a newly discovered
  built-in keyboard moves first. Saved exclusions without a current row
  append after them.
- The keyboard list scrolls independently; `Continue` stays reachable when every
  listed keyboard is excluded.
- Exclusions remain filtered from Activity-Triggered Switching. The Settings
  Excluded Devices section remains available after onboarding.

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
  `Not a Keyboard` is an item in that menu rather than a button on a card, and
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
- The excluded device leaves the active Physical Keyboard list, produces no
  Activation Activity, opens no Switching Status warning, and cannot be retried:
  an exclusion clears the wanted Keyboard Assignment and selection-failure
  warning that named it. Onboarding and Settings show a separate excluded row.
- The exclusion set lives in `UserDefaults` under
  `keyameleon.excludedPhysicalKeyboards` as JSON, next to the guided-setup
  decisions. `PhysicalKeyboardSchemaV1` keeps its two models and
  `PhysicalKeyboardMigrationPlan.stages` stays empty.
- Nothing removes an exclusion automatically. Onboarding and Settings offer an
  explicit restore action, because every disconnect signal is also sleep, lock,
  and pause.
- Guided setup offers `Not a Keyboard` on its Physical Keyboard card. Settings
  offers `Disable` in the card menu. Both use the `Not a Physical Keyboard?`
  confirmation, and neither action deletes saved names or assignments.

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
  parameter on `SetupModel`, `ActivityTriggeredSwitching`,
  `GeneralSettingsModel`, and the composition root.
- One process-wide `Log` with four levels (`verbose`, `debug`,
  `warning`, `error`) and three categories (`app`, `switching`, `setup`). A call
  site emits one line and carries no logger, so nothing threads a destination
  through the models that used to take a diagnostic controller.
- The process is silent until `Log.start` installs a writer at launch.
  Hosted unit tests and SwiftUI previews never install one, so they cannot write
  to the user's Logs folder.
- `LogWriter.file` appends to `~/Library/Logs/Keyameleon/keyameleon.log`
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
- Remove the store from `ApplicationDelegate` and
  `GeneralSettingsModel`, including the `hasPendingUncleanExitNotice`
  flag and its dismiss action.
- Two `UserDefaults` keys, `keyameleon.lifecycle.activeLaunch` and
  `keyameleon.lifecycle.pendingUncleanExitNotice`, are left behind on existing
  installs. They are inert and not worth a cleanup pass.
- A crash leaves no marker. The previous run never wrote its `Terminating` line,
  so the log file shows it, and the next launch appends to the same file.

## 2026-09-22 — Logging review round

### Defaults

- One file per type, following the project structure rule in `AGENTS.md`. The
  logging pipeline is now `Log`, `LogFile`,
  `LogWriter`, `LogLevel`, and `LogCategory`.
- `PhysicalKeyboardDiscoveryRecordChange` carries the Physical Keyboard Name.
  Discovery removes a keyboard from the catalog before it publishes a disconnect,
  so a subscriber that looked the name up read `name unknown` for every real
  disconnect.
- `LogWriter.appendOnlyFile` serves the single-instance exit path. A
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
- Test-only `ApplicationDelegate` initializer defaults to `NoOpPhysicalKeyboardDiscoverer`, `NoOpPhysicalKeyboardEventObserver`, `NoOpInputSourceChangeObserver`, and `NoOpKeyameleonLifecycleObserver`.
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
  - 2026-10-07: superseded. The release workflow updates the cask in `mastro993/homebrew-tap`.
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
- `MenuBarPanelController` / `ApplicationDelegate` — Escape and outside-click close the transient popover only.

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
  - 2026-10-07: the cask exists. README lists Homebrew first, then the DMG.
- Screenshot: placeholder + intended-shot description. No image file in this pass.
- Features: full user-visible surface, short bullets.
- Privacy: own README section.
- Maintainer block: build commands, short architecture, Official Release workflow + secrets table. Detail remains in `docs/release/official-release.md`.

## 2026-08-14 — Issue #50 Menu-bar Quick Actions, recovery banner, footer

### Seams

- `MenuBarPanelContent` — `MenuBarAssignmentList` plus footer. Overflow actions are typed here. Tests live here.
- `MenuBarPanelView` — renders keyboards and footer only.
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
- `SetupModel.requestPermission()` — Guided setup action: request listen permission, then open System Settings only if Switching Status stays Permission Required.
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

- `MenuBarPanelController` — one AppKit module: show, toggle, and close one transient 320 pt `NSPopover` anchored to the existing `NSStatusItem` button. Refresh runs before presentation.
- `MenuBarPanelContent` — typed Menu first rows and actions. `MenuBarPanelView` renders that content on one native popover glass surface.
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
- `SetupModel` — permission and Unavailable Keyboard Assignment episode boundaries.

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
- `Scripts/verify-official-release-tag.sh` validates the Official Release tag shape (`vMAJOR.MINOR.PATCH`).
- `Scripts/write-release-evidence.sh` writes JSON that binds the artifact SHA-256 to its source tag and commit.

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
- **`SetupModel.forgetPhysicalKeyboard`**: also deletes Diagnostic Data linked to that Physical Keyboard.
- **`GeneralSettingsModel`**: Diagnostics section (session + clear).

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
- **Recovery coordinator** on `SetupModel`: one warning per active cause, `retryNow()`, skip select for unavailable, reevaluate on Input Source refresh.
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
- `SetupModel` session: start → leave → return → confirm name; other Physical Keyboards stay assignable.

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
- `SetupModel.handlePhysicalKeyboardEvent` — serial activity consumer (observation order).
- Wanted Keyboard Assignment generation on `SetupModel` — bump per select need; discard stale readback.
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
- **Switching coordinator** via `SetupModel`: Active Physical Keyboard, request exact Keyboard Assignment, exact identifier readback.
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
- `UpdatePolicy` — pure constants for 24h interval, no auto-install, no system profile, no Keyameleon-generated identifiers.
- `GeneralSettingsModel` — General settings presentation over those seams.
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

- **Seams under test**: `PhysicalKeyboardRecordStoring` and `SetupModel` (application-service seam from parent #1). Catalog unit rules stay in domain tests.
- **Active Physical Keyboard**: in-memory only on `SetupModel`; not persisted across app restart. `noteActivationActivity` remains a test/manual seam; real switching uses `handlePhysicalKeyboardEvent`. Lifecycle slice never increments Input Source selection requests.
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
- Runtime application identity comes from the application bundle. Release scripts determine published product and artifact identity.
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

- `MenuBarPanelView` returns focus to the silent container whenever one of the app's windows becomes key, which is the moment the popover is shown.
- The popover reuses one content view across shows, so `onAppear` and `onDisappear` do not run per show. The key transition is the only per-show signal the view gets.
- Keyboard focus order, the silent container, and `focusEffectDisabled(focusedTarget == .container)` stay as shipped in #51.

## 2026-09-30 — Persistence failures preserve saved keyboard records

Physical Keyboard records and Manual Physical Keyboard Designations share one explicit SwiftData transaction. Autosave is disabled. Rename, assignment, forget, replacement, and designation changes publish success only after the complete transaction saves. A failed fetch or save rolls back pending changes; failed writes retain the requested operation for Retry. Built-in identity migration is marked evaluated only after its reads and any transfer succeed.

`SavedPhysicalKeyboardChanges` owns those five saved changes, their transaction,
and one pending change for exact Retry. Its interface accepts typed domain values
and returns the committed change only after save and synchronous record
notifications finish. A failed change blocks later saved changes until Retry
succeeds or a pending Manual Physical Keyboard Designation is canceled.
The module uses the existing record and designation adapters with one shared
SwiftData session; tests and previews can use the concrete in-memory pair.
`SetupModel` keeps eligibility checks, designation evidence, and display
and switching effects. First attempts and Retry use the same completion path.
Saved reads and Activity-Triggered Switching read recovery remain with their
existing modules.

Input Source selection reads the saved keyboard name before requesting the change, including Retry Now. If that read fails, no selection request or verified assignment is published. The success and failure logs reuse the name already read.

If the saved store cannot open or be read, Keyameleon stays running and shows an unavailable notice with Retry in guided setup, Settings, and the menu panel. The last successfully read keyboard list, assignments, and warnings remain available for display. Permission, pause, and lifecycle status continue to update, including stopping discovery while asleep or locked. Activity-Triggered Switching does not select an Input Source using missing or fabricated saved data. Retry reopens the same store or retries the failed change. Keyameleon never deletes, recreates, or substitutes an in-memory store for unreadable user data.

## 2026-10-01 License

Keyameleon uses the MIT license. Release evidence and About display the SPDX
identifier `MIT`. Every build bundles the complete MIT text from `LICENSE`.
Third-party licenses remain unchanged.

## 2026-10-01 Release and update policy ownership

Release scripts own Official Release tag validation and evidence generation.
Script tests exercise the commands used by the release workflow, including
strict tag syntax, artifact naming, the emitted SHA-256, and invalid inputs.
The app has no separate release-evidence model or tag parser.

Sparkle owns update scheduling through the shipped Info.plist configuration.
`UpdatePolicy` retains the configuration values used by the updater
and checked against the app bundle. It does not calculate when a check is due.

## 2026-10-03 — Guided setup finishes from Ready

Guided setup has three saved stages: Permissions, Keyboards, and Ready. Input Monitoring is checked when the window opens; a granted permission advances Permissions automatically. An unsuccessful explicit permission request leaves recovery controls to open System Settings or check again. Closing the window stops permission polling, and reopening resumes the saved stage.

The Keyboards stage saves each assignment and exclusion immediately. Continue and Set Up Later both reach Ready, even with no assignments. Back returns to Keyboards without discarding changes. Ready reports the saved assignment count and current switching status, including paused, unavailable, and missing permission conditions. Finish closes setup and leaves Keyameleon in the menu bar. Open Settings closes setup before opening Settings. Completion is persisted before either action and handled once. This replaces the older setup completion behavior that opened Settings directly from the assignment stage.

## 2026-10-05 Menu-bar panel follows the Pencil design

The menu panel uses the existing SwiftUI components in a 320-point native transient popover. `Theme.Menu` owns its measured dimensions and native semantic colors. macOS owns the outer glass and radius. Active assignments have an accent fill and border; connected and disconnected rows have no card border. Status symbols are `circle.fill`, `circle`, and `circle.dashed`. Subtitles show Built-in, Active, Connected, or Disconnected, prefixed by the product name when a custom name is shown.

The header shows `(Paused)` inline. Pause Switching and Resume Switching share Command-P. Settings uses Command-comma, and Quit Keyameleon uses Command-Q. The typed shortcut descriptor supplies both each visible hint and its native binding.

The Input Monitoring required notice prefers Open System Settings when available and closes the panel before opening that external window. Request Permission remains the fallback and keeps the panel open. An unavailable recovery action is omitted. Assignment filtering, ordering, the five-row scroll threshold, Guided Setup continuation, persistence recovery, and focus order remain unchanged.

## 2026-10-05 — Native status menu replaces the custom panel

The status item owns an `NSMenu`. AppKit draws the title, notices, commands, separators, shortcuts, tracking, and dismissal. Only Keyboards uses the existing SwiftUI assignment list in `NSHostingView`; its assigned-only order, unavailable-source state, and five-row viewport remain. The controller updates native items from the typed `MenuBarPanelContent` snapshot as models change and before the menu opens. Stable menu items and the keyboard host stay attached during updates, preserving the list's scroll position.

The native section header shows `Keyameleon v<marketing version>` from `CFBundleShortVersionString`, with ` (Paused)` only while switching is paused. A missing or blank version shows `Keyameleon v—`. The footer has actions only, with Quit Keyameleon last.

All selected commands close the menu, including Pause, Resume, Request Permission, Retry Now, and saved-data Retry. Saved-data Retry calls `SetupModel.retryPersistenceOperation()` and has its own typed action ID. Menu rows have no hover tooltips; notice subtitles, visible keyboard warnings, and accessibility text retain the full explanation. The old warning card and popover focus rules no longer apply. Earlier entries describe the superseded panel design.

Check for Updates… is a native row directly below Settings in every menu state, with no shortcut or tooltip. The row uses the shared General settings availability snapshot, refreshed when the menu opens. Selecting it uses the existing application update command and disables the row while a check is busy; reopening the menu samples readiness again after the check completes.

## 2026-10-06 Menu notices replace the keyboard region

The native menu keeps its heading, footer commands, shortcuts, and usual width. Its middle region contains either the Keyboards heading and assignment list or one hosted SwiftUI notice. A notice has a wrapping title, explanation, and full-width CTA within `Theme.Menu.width` (320 points). Copy gives only the state and the next action. It keeps the actual temporary-unavailability reason, Input Source names for a mismatch, and unassigned keyboard names or count. Saved-data recovery uses a fixed short instruction rather than storage-error details. Warning notices use a subtle yellow surface; other notices use a neutral surface and semantic primary and secondary text.

Saved-data failure takes precedence over switching notices and uses the warning tone with Retry. Permission recovery prefers the available Open System Settings or Request Permission action, falling back to Open Settings when neither is available. Selection failure offers Retry Now only when available, otherwise Open Settings. Temporary unavailability, mismatch, and unassigned keyboards offer Open Settings; unfinished Guided Setup offers Continue Guided Setup. Each CTA uses a native `NSButton` inside the hosted SwiftUI notice so its target-action callback runs during native menu tracking. It closes menu tracking before dispatching its existing action and honors the action's enabled state. The notice's native menu item carries the same action, title, and enabled state for keyboard activation. Refreshing a notice updates both activation paths while preserving the menu item and width.

Resolving the notice restores the keyboard region. Ordinary keyboard refreshes reuse its host to preserve scrolling; transitions between notices and keyboards may recreate it. Earlier native-menu entries describe the superseded notice rows and simultaneous keyboard list.

## 2026-10-06 — Menu-bar keyboard list drops its section label

The keyboard region is the assignment list alone. The native `Keyboards` section header is gone, so the list sits directly under the `Keyameleon v<marketing version>` heading, and `MenuBarAssignmentList` no longer carries the heading copy. The list keeps a 4-point horizontal inset from the panel edges (`Theme.Menu.listInset`), smaller than the shared `rowInset`. Assigned-only order, the five-row scroll viewport, and the notice replacement rules stay the same. Earlier entries describe the superseded heading and full-width list.

## 2026-10-06 — Input Monitoring recovery guide

Open System Settings uses one shared native guide for Guided setup and the menu's permission recovery. After System Settings opens successfully, unknown or denied Input Monitoring access shows a small nonactivating floating panel. It does not request permission, activate Keyameleon, or change the behavior of Request Permission. Repeated opens reuse the same panel. Granted access shows no panel.

The icon drags the running application's actual `.app` bundle as a file URL with a copy operation. Show in Finder provides a keyboard-accessible alternative for locating that same application; Close dismisses the guide. The guide uses the existing Theme and native app icon.

Window Server metadata identifies System Settings by process ID and bundle ID. It follows the visible window on its display, preferring below and falling beside it when space is limited. Coordinates use the primary display's global origin, including displays above or left of it. Placement stays inside the display's visible frame and pauses during the icon drag. No Accessibility or Screen Recording access is requested. Unavailable metadata leaves the guide movable; it is not treated as proof that Settings closed. Initial Settings launch has a five-second grace period before a missing window closes the guide.

One cancellable task checks window placement and the existing IOHID permission provider every 750 milliseconds. An actual grant closes the panel, refreshes Activity-Triggered Switching, and advances incomplete Guided setup. Completing a drag alone never grants access. Dismissal, observed Settings window closure, and application termination stop the task. This also covers recovery after Guided setup is complete.

## 2026-10-06 — Independent development app

Superseded 2026-10-07. Debug now shares the shipped identity: bundle ID `dev.fedemas.keyameleon`, name `Keyameleon`, the shipped defaults domain, SwiftData store and legacy store migration, logs folder, installation integrity keychain item, and the `/dev/null` lock (ADR 0002). Data from `Keyameleon (Dev)` stays at `~/Library/Application Support/Keyameleon (Dev)/default.store` and its defaults domain, logs folder, and keychain item remain untouched; Keyameleon does not import, overwrite, or delete them. Debug and CI builds never start Sparkle because they lack the Official Release `SUPublicEDKey`. `run.sh open` stops only this checkout's Debug app and refuses to stop another running Keyameleon; `run.sh test` cleanup stops only the Debug app under `./build`.

## 2026-10-06 Stable Debug signing for Xcode Run

Project-level Debug settings require Manual signing and resolve their identity through `Config/Development.xcconfig`, so the app and hosted test bundles inherit the same identity. The generic `Apple Development` class alone makes Xcode require a team or provisioning profile. `run.sh generate` selects the first installed Apple Development certificate fingerprint and writes it to the ignored `Config/Development.local.xcconfig`, which the tracked config optionally includes. Without a certificate, generation clears the local selection and leaves the generic default in place so normal Debug builds fail rather than fall back to ad hoc signing. No personal team or certificate identifier is committed. Xcode Run and script builds no longer default to ad hoc signatures, which can invalidate Input Monitoring grants across rebuilds. `run.sh test` explicitly opts both test build and execution commands into ad hoc signing for certificate-free CI. Release settings are unchanged. `run.sh open` uses the same certificate selection helper and fingerprint. A real grant and rebuild check remains necessary to verify permission retention.
