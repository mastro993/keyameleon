# Design decisions

This document describes how Keyameleon behaves today and why, grouped by feature. Product terms in **bold** are defined in [`CONTEXT.md`](../CONTEXT.md). The most consequential decisions also have an [ADR](adr).

When behavior changes, edit the relevant section in place rather than appending a dated entry. Superseded decisions live in git history and pull requests; [`breadcrumbs.md`](breadcrumbs.md) keeps a short chronological work log.

## Principles

- **Monitor-only.** Keyameleon observes keyboards through CoreHID in listen-only mode and changes layouts only through the Text Input Sources API. It never seizes, injects, or alters input. The [safety audit](development.md#safety-audit) enforces this.
- **Key Content stays in classification.** Keystrokes, modifiers, shortcuts, and keyboard state never reach saved data, logs, the network, or crash state.
- **No telemetry.** No analytics, no notifications, no automatic uploads. Sparkle update checks are the only network traffic.
- **Nothing silent or substituted.** Keyameleon never picks a replacement Input Source, never deletes or recreates unreadable user data, and never moves saved data between changed identities without an explicit rule or user action.
- **Copy belongs to its view.** Each view owns its user-visible strings; there is no shared copy registry. Domain types expose typed facts, not text.

## Physical Keyboards

### Recognition

Keyameleon inspects every CoreHID device, because keyboard collections can sit behind a pointer or vendor-defined primary usage. A device is a **Physical Keyboard** when it can produce **Activation Activity**: its primary or device usages include keyboard, keypad, or consumer (media key) usage, or it exposes a keyboard, keypad, or consumer input element. Recognition and Activation Activity observation share one element rule, so any device that can switch layouts is listed. LED output is not required, and pointer usage does not disqualify a device.

This broad rule prefers listing too many devices over missing a keyboard, such as a 2.4 GHz receiver whose keyboard collection is not advertised. The cost is listing some devices that are not keyboards, such as a mouse with shortcut buttons, a headset with volume buttons, or a display with media controls. The person ignores those (see [Ignoring devices](#ignoring-devices)) rather than Keyameleon guessing.

Recognition is separate from assignment: a device can be listed without being assignable.

### Identity

A **Keyboard Assignment** requires a stable, unique **Physical Keyboard Identity**.

- **External keyboards** use their USB serial number, or for Bluetooth LE keyboards without one, their Bluetooth device address. A device with neither, such as a 2.4 GHz receiver, falls back to its vendor and product IDs, so every HID interface of the receiver forms one row that survives reconnects and port changes. CoreHID's software IDs change on reconnect and differ per interface, so they are not used for these fallbacks.
- The vendor and product fallback names a model, not one device. When identical devices without serial numbers are connected at once (seen as different USB `locationID`s), they share one row marked unsupported as `Identity shared` rather than Keyameleon guessing which is which.
- A keyboard without any stable, unique identity, including one with vendor and product IDs of zero, is listed as unsupported, with the reason shown.
- **The built-in keyboard** is one fixed identity covering every CoreHID service macOS marks as built-in, independent of software or hardware identifiers ([ADR 0003](adr/0003-built-in-physical-keyboard-identity.md)). Its default name is the shared macOS product name, or `Built-in Keyboard` when services disagree.
- When an identity changes, Keyameleon does not move or delete saved names, assignments, or designations automatically. The one exception is the one-time built-in migration in ADR 0003.

### Manual designation, replacement, and forgetting

These exist in the model, with tests, but **have no UI entry point** since Settings was rebuilt.

- **Manual Physical Keyboard Designation** lets the person vouch for an external keyboard whose identity is ambiguous across interfaces. It is offered only for external, identity-based devices marked ambiguous; it requires the device to leave and return and the person to confirm its name. The saved evidence is authenticated with an HMAC (CryptoKit) whose key lives in the Keychain item `dev.fedemas.keyameleon.installation-integrity`. Tampered evidence leaves the device unsupported. A designation saves a name only, never an assignment.
- **Replace** moves a saved name and assignment from a disconnected saved keyboard to a new identity, after confirmation.
- **Forget** deletes a saved keyboard's name, assignment, and designation. Connected hardware reappears as a new, unassigned keyboard.

### Ignoring devices

A **Physical Keyboard Exclusion** (shown as **Ignore** in the UI) marks a device as not a keyboard.

- It is keyed by the device rather than a CoreHID service: the identity value without its anchor, or the vendor, product, and model when there is no identity. The built-in keyboard has no key, so it can never be ignored, even by a stale saved value.
- Ignoring is a filter, not a deletion. The saved name, assignment, and designation survive and come back on Stop ignoring.
- An ignored device produces no Activation Activity, never becomes the Active Physical Keyboard, raises no warning, and cannot be retried; ignoring clears any pending assignment and selection warning for it.
- It persists across disconnect, restart, and the catalog reset that sleep, lock, and pause perform. Nothing removes it automatically, because every disconnect signal also fires for sleep, lock, and pause.
- Exclusions are stored as JSON in UserDefaults under `keyameleon.excludedPhysicalKeyboards`, so the SwiftData schema did not change.

### Lists and naming

- Guided setup and Settings share one keyboard list (`PhysicalKeyboardRows`) and row view. Ignored keyboards stay in place, dimmed, with their saved Input Source shown in a disabled picker.
- The built-in keyboard is always first, even when it is discovered after other rows. Other rows keep their order and identity for the session; new keyboards are appended.
- A row shows the **Physical Keyboard Name** (the custom name, or the product name) and its connection status: `Connected` or `Disconnected`, prefixed by `<product> - ` when a custom name hides the product name, with ` (Ignored)` appended for ignored rows.
- Pickers show `Unassigned` when there is no assignment. Missing or ambiguous saved records show a disabled `Unassigned` picker rather than an assignment borrowed from another record.
- The row's trailing menu offers **Rename…** (when the identity is safe) and **Ignore**, or **Rename…** and **Stop ignoring** for an exact ignored record. Missing or ambiguous ignored records offer only Stop ignoring. The built-in keyboard reserves the menu space but offers nothing. Changes save immediately; a persistence failure disables the picker and menu.
- Renaming uses a sheet with the product name as the placeholder; clearing the field restores the product name.

## Activity-Triggered Switching

`ActivityTriggeredSwitching` is the single switching module. It exposes one immutable outcome and seven operations: start, stop, request permission, check again, pause, resume, and retry now. Discovery, Input Source selection, and record storage stay behind their own modules.

### Switching

- Only **Activation Activity** (a key press or repeat) makes a keyboard active; release-only events do not. The **Active Physical Keyboard** is never persisted across restarts.
- Keyameleon requests the exact assigned Input Source and reads it back to verify. It does not delay or change the triggering event, so that event and anything macOS handles before verification can use the previous Input Source.
- Requests are serialized in observation order and tagged with a generation, so stale readbacks from rapid typing across keyboards are discarded.
- A request is skipped when the wanted assignment is already verified and current. Two keyboards assigned to the same Input Source therefore switch the active keyboard without selecting again.
- If the person changes the Input Source manually or another app does, Keyameleon records it and shows the mismatch but does not fight it. The next Activation Activity reapplies the assignment.
- Before selecting, including on Retry Now, Keyameleon reads the keyboard's saved name. If that read fails, it selects nothing.

### Failures and recovery

- **Selection failure:** the previous Input Source is restored when the readback does not match. One warning tracks the current wanted assignment, with **Retry Now**. There is no timed retry loop.
- **Unavailable Keyboard Assignment:** when an assigned Input Source disappears from macOS, the assignment is kept, nothing is selected in its place, and a warning shows. It clears when the exact Input Source returns.
- **CoreHID streams** resubscribe after any exit other than cancellation, with a one-second delay so a failing Mac cannot loop tightly.

### Switching Status

**Switching Status** resolves in priority order: Permission Required, then Temporarily Unavailable, then Paused, then Ready.

- **Temporarily Unavailable** covers sleep, an inactive login session, Secure Input, and unavailable protected data. Discovery stops while asleep or locked.
- **Pause** is persisted (`keyameleon.activityTriggeredSwitching.paused` in UserDefaults). It stops observation and Input Source requests but keeps discovery running so keyboards can still be managed. Resume clears the pause, rechecks permission, and starts observation only if Ready.
- The status item icon uses a distinct SF Symbol shape per state, not just a color. Per-keyboard warnings show on the icon only when the status is Ready.

## Input Monitoring permission

- `Info.plist` must include `NSInputMonitoringUsageDescription`; without it, `IOHIDRequestAccess` fails silently with no prompt.
- **Request Permission** activates the app, requests listen access, and opens **System Settings → Input Monitoring** only if access is still missing.
- **Open System Settings** opens Input Monitoring and, when access is unknown or denied, shows a small non-activating guide panel. Guided setup and the menu notice share it. The guide:
  - offers the running app's `.app` bundle as a draggable file, with **Show in Finder** as the keyboard-accessible alternative;
  - follows the System Settings window (found by process and bundle ID in Window Server metadata) on its display, below it or beside it when there is no room, across multi-display layouts, without requesting Accessibility or Screen Recording access; if metadata is unavailable it stays movable;
  - checks placement and permission every 750 ms in one cancellable task, with a five-second grace period for System Settings to launch;
  - closes on an actual grant (a drag alone is not a grant), then refreshes switching and advances Guided setup. Dismissal, closing System Settings, or quitting stops it.

## Persistence

- Keyboard names, assignments, and designations live in SwiftData at `~/Library/Application Support/Keyameleon/default.store`. Setup progress, exclusions, and pause state live in UserDefaults; the integrity key lives in the Keychain. Copying the store alone (with its `-wal` and `-shm` files, while Keyameleon is quit) is not a complete backup.
- **Legacy store migration:** an older store at `Application Support/default.store` is copied with SQLite's backup API into a staging folder, then moved into place. An existing destination always wins, the legacy files are never touched, and a failed copy is retried on the next launch. A migration failure stops startup of the store rather than opening an empty one.
- **Transactions:** records and designations share one explicit SwiftData transaction with autosave off. `SavedPhysicalKeyboardChanges` owns the five saved changes (rename, assignment, replace, forget, designation). A change reports success only after the whole transaction saves; a failure rolls back, keeps the request for an exact Retry, and blocks later changes until Retry succeeds or a pending designation is cancelled.
- **Unreadable data:** if the store cannot be opened or read, Keyameleon keeps running with the last successfully read state and shows a notice with Retry in Guided setup, Settings, and the menu. It never deletes the data, recreates the store, or substitutes an in-memory store, and switching never acts on missing or invented data.
- Hosted tests and Xcode previews use in-memory stores.

## Guided setup

Guided setup has three saved stages: **Permissions**, **Keyboards**, and **Ready**.

- Permission is checked when the window opens, and a grant advances Permissions automatically. An unsuccessful request leaves controls to open System Settings or check again.
- Keyboards saves each assignment and exclusion immediately. Continue and Set Up Later both reach Ready, even with no assignments. Back returns to Keyboards without losing changes. The step is one scrolling region (progress, explanation, rows, note) above a footer that stays reachable.
- Ready reports the number of assignments and the current switching state, including paused, unavailable, and missing permission. **Finish** closes setup and leaves the menu bar app running; **Open Settings** closes setup, then opens Settings. Completion is saved first and handled once.
- Closing the window stops permission polling and keeps the saved stage. While setup is incomplete, the menu offers **Continue Guided Setup** in every state.

## Menu bar menu

The status item owns a native `NSMenu`. AppKit draws the heading, notices, commands, separators, shortcuts, tracking, and dismissal. Keyameleon stays on `NSStatusItem` rather than `MenuBarExtra`.

- **Heading:** `Keyameleon v<marketing version>`, with ` (Paused)` while paused, or `Keyameleon v—` when the version is missing.
- **Middle region:** either the keyboard list or one notice, never both.
  - The keyboard list is SwiftUI hosted in the menu, showing assigned keyboards only: the built-in keyboard first, then connected, then disconnected, alphabetical within each group. It has no section label, a 4 pt inset, and a five-row scrolling viewport. Ordinary updates reuse the host to keep the scroll position.
  - Each pill is one line: connection mark (`circle.fill`, `circle`, or `circle.dashed`), the Physical Keyboard Name, an optional warning triangle, and a filled locale-code badge (such as `US` or `IT`, resolved from the layout's primary language and its canonical region). The active keyboard gets an accent fill and border. Disconnected pills are dimmed (more opaque under Increase Contrast), except the warning triangle.
  - A notice has a title, a short explanation, and one full-width button. A saved-data failure is a yellow notice with Retry and outranks everything else. Missing permission is yellow and offers Open System Settings, then Request Permission, then Open Settings, whichever is available first. Selection failure offers Retry Now when available. Other notices are neutral and open Settings or Continue Guided Setup. Buttons are native `NSButton`s so they work during menu tracking, and the notice's menu item carries the same action for keyboard activation.
- **Commands:** Pause or Resume Switching (<kbd>⌘</kbd><kbd>P</kbd>), Settings (<kbd>⌘</kbd><kbd>,</kbd>), Check for Updates… directly below Settings, and Quit Keyameleon (<kbd>⌘</kbd><kbd>Q</kbd>) last. Every command closes the menu. There are no tooltips and no About item; About lives in Settings.
- The menu refreshes permission, Input Sources, and status before it opens.

## Settings

Settings is a branded window with a sidebar and three panes: **General**, **Keyboards**, and **About**. It reopens on the last pane and has an 840 × 560 minimum size, enforced by both the window and the SwiftUI content.

- The sidebar is a native `List(selection:)` with the keycap mark from the official logo. Panes use grouped `Form` and `Section` with platform margins and row insets, and no per-pane padding.
- **General:** Launch at login (via `SMAppService.mainApp`) as a native toggle whose label includes the explanation. If a change fails, the toggle shows the real service state and adds Login Items guidance.
- **Keyboards:** the shared keyboard list. The Input Source control is a bordered menu hosting a native picker in a fixed 176 pt column so every row lines up. With no keyboards, a native `ContentUnavailableView` reads `No keyboards detected`, unless saved data is unreadable, in which case only the Retry notice shows.
- **About:** app icon, name, and tagline; rows for version (with build number), source code, app data folder, logs folder, license, and updates; the Sparkle acknowledgement; and the creator credit, which scrolls with the pane. Folder paths are selectable and open in Finder. License rows open the bundled `LICENSE.txt` and `Sparkle-LICENSE.txt` and are disabled if the build lacks them.

Guided setup and Settings share `Theme` for colors and type, so the two windows cannot drift. Links use SwiftUI `pointerStyle`, and the menu's pill animation is disabled under Reduce Motion.

## Logging

- One process-wide `Log` with four levels (`verbose`, `debug`, `warning`, `error`) and three categories (`app`, `switching`, `setup`). Call sites emit one line without passing a logger around.
- Nothing is written until `Log.start` installs a writer at launch, so tests and previews never touch the real Logs folder.
- The writer appends to `~/Library/Logs/Keyameleon/keyameleon.log` through one `O_APPEND` descriptor, rotates at 1 MiB, and keeps five rotated files. It collapses line breaks inside a message, truncates oversized records, and reopens the file if it is deleted or replaced. Every file operation is best effort and never interrupts switching.
- A line holds the timestamp, level, category, and message. Keyboard lines use the Physical Keyboard Name (the saved custom name first), never identities, paths, system error text, or Key Content.
- Logged events include launch, termination, store and Launch at Login failures, update checks, connections and disconnections, changes of Active Physical Keyboard, selection results, status changes, permission, and assignment changes. There is no line per keystroke; `verbose` covers external Input Source changes.
- A blocked second launch appends one line without rotating, so it never renames a file the running app holds open.
- A crash leaves no marker; the missing `Terminating` line shows it.

## Updates

Sparkle 2 handles updates, configured in `Info.plist` and mirrored by `UpdatePolicy`:

- Automatic checks at most every 24 hours. Automatic download and installation are off and cannot be enabled; critical updates also need approval.
- No system profiling and no Keyameleon-generated identifiers.
- Feed: `https://mastro993.github.io/keyameleon/appcast.xml`. GitHub Pages serves project sites under the lowercase repository path; a capitalized path made `0.4.0` and `0.4.1` unable to update. The Release workflow now reads the feed URL back from the built app and checks that the live feed serves the new version before publishing.
- Only Official Release builds include `SUPublicEDKey`. Debug and CI builds never start Sparkle.
- **Gentle reminders:** Keyameleon is a background app, so for a scheduled update it temporarily becomes a regular app with Dock badge `1`. Paying attention clears the badge, and the end of the update session restores menu-bar-only mode. Sparkle still shows its own alert. A check the person starts changes nothing.

## Single instance

Only one Keyameleon process runs per Mac, across users, locations, versions, and Debug builds ([ADR 0002](adr/0002-one-keyameleon-instance-per-mac.md)). The lock is an advisory lock on `/dev/null`, which every user can open and nobody can delete. Later launches exit silently, and direct executable launches return a nonzero status.

## Testing and CI

See [Testing](testing.md). In short: one focused macOS 26 suite plus the safety audit ([ADR 0001](adr/0001-product-validation.md)); hosted tests never start live surfaces ([ADR 0005](adr/0005-hosted-unit-tests-skip-live-surface.md)); there is no UI-test target; and documentation-only changes skip the macOS job behind one stable required check.

## Official Releases

See [Official Release](release/official-release.md). In short:

- A release starts only from the Release `workflow_dispatch` on `main`, choosing `patch`, `minor`, or `major` ([ADR 0004](adr/0004-official-release-workflow-dispatch.md)). The latest release tag on `main` is the version authority. The workflow commits `MARKETING_VERSION` to `main` as `chore(release): X.Y.Z`, and the tag, evidence, DMG, and GitHub Release all point at that commit.
- Each release ships one signed, notarized DMG on GitHub Releases, with the appcast and permanent evidence on GitHub Pages ([ADR 0006](adr/0006-dmg-only-official-release-distribution.md)), and updates the Homebrew cask in the shared `mastro993/homebrew-tap` once everything else is verified. The cask uses `auto_updates true`, so Sparkle stays the updater. Listing in the official `homebrew/cask` waits until the project passes Homebrew's notability audit.
- A release is immutable: an existing version fails, and retries reuse the exact signed bytes.
- The appcast holds the latest item only, without Sparkle deltas.
- Release notes come from git history since the previous release, with `@login` mentions that GitHub turns into the Contributors card. There is no `CHANGELOG.md`.
- Release scripts own tag validation and evidence generation, with Python tests in `Tests/Scripts`.
- The project is MIT licensed, and every build bundles the license texts (see [Bundled licenses](release/official-release.md#bundled-licenses)).
