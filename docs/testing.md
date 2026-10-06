# Testing

Run the complete local check with:

```sh
./Scripts/run.sh test
```

This command runs the safety audit, SwiftLint, and the focused automated product
tests on macOS 26. SwiftLint runs before the Xcode project generation and build.
The command runs Swift Testing and XCTest bundles serially, then kills
leftover Keyameleon processes whose executable is under `./build`. Tests should
protect one distinct user-visible outcome or one critical safety rule. Prefer
domain and model seams; this repository has no automated UI-test target.

## SwiftLint

Install SwiftLint **0.65.1** from its
[official release](https://github.com/realm/SwiftLint/releases/tag/0.65.1).
The portable macOS archive has SHA-256
`c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0`.
CI and the Official Release version-commit job download that archive and verify
its checksum before running the test command.

Run the source check without an Xcode build:

```sh
./Scripts/run.sh lint
```

Local checks and CI use `.swiftlint.yml` and the same command:

```sh
swiftlint lint --strict --quiet --no-cache --config .swiftlint.yml
```

The configuration pins the tool version and checks all of `Sources`, including
preview fixtures. A different version, a warning, or an error fails the check.
The default rules remain enabled. There is no saved violation baseline.

The project uses explicit size limits for its existing state models, SwiftUI
screens, and preview fixtures. Strict mode fails above 1000 lines per file,
800 lines per type body, or 120 lines per function body. These limits avoid a
behavioral refactor solely to satisfy SwiftLint's smaller default limits while
still detecting further growth. Type and identifier names allow 60 characters
so that names can use the full domain vocabulary. The default minimum lengths
and character checks remain active.

Cyclomatic complexity keeps the default limits but excludes `switch` cases.
Exhaustive domain-enum mappings do not increase the count. Conditional branches
and loops still count. No correctness rule is disabled by this policy.

When updating SwiftLint, update the version in `.swiftlint.yml` and the download
URLs and checksums in both CI and Release workflows together. Recheck the source
baseline before changing the pin.

## Product tests and CI

Hosted unit-test processes (`KeyameleonSwiftTesting`, `KeyameleonXCTest`) must
not start live CoreHID observation or the menu-bar status item. Detect them
with `XCTestConfigurationFilePath` or `XCTestBundlePath`. See
`docs/adr/0005-hosted-unit-tests-skip-live-surface.md`.

Hosted app startup and Xcode previews use in-memory SwiftData storage. Store
relocation and persistence failure tests use disposable directories and must
never migrate or modify the user's real data.

Saved Physical Keyboard changes are tested through the
`SavedPhysicalKeyboardChanges` interface with the real SwiftData adapters. The
tests cover rollback across both stores, exact Retry, blocked competing changes,
and notifications after commit for rename, assignment, replacement, forget, and
designation. Model tests cover the displayed failure, opening recovery, and
designation cancellation without canceling an unrelated pending change.

CI uses one stable required check, `Required CI gate`, with two paths:

- Changes outside the paths in CI's `Check whether code changed` step, such as
  documentation-only changes, do not run tests or use a macOS runner.
- Build-affecting changes include app source, bundled resources under `Resources`
  and `Keyameleon-icon.icon`, bundled legal texts from `LICENSE` and
  `THIRD_PARTY_NOTICES.md` (including modifications and deletions), tests,
  project and package configuration, `.swiftlint.yml`, `Scripts`,
  `.github/workflows/ci.yml`, and `.github/workflows/release.yml`. These changes
  run SwiftLint, the complete macOS product tests, and the safety audit.

The macOS job has an eight-minute limit and no automatic retry. A maintainer can
rerun an infrastructure failure after inspection. The `main` branch ruleset
requires `Required CI gate` from GitHub Actions for pull-request merges. Do not
require the conditional `Build and test` job: skipped jobs can satisfy a required
check even when the aggregate gate fails. Repository administrators retain the
emergency override.

Keep these rules as hard failures:

- Keyameleon remains monitor-only and never injects or changes Physical Keyboard Events.
- Key Content does not enter saved data, log files, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

Do not add repeated suites, fixed event counts, participant quotas, qualification
evidence files, endurance runs, or performance thresholds without a real product
failure that needs them. Official Release artifact evidence remains separate.

### Guided setup

Run `./Scripts/run.sh test` after changes to setup state, assignment controls, or window lifecycle. Verify that an incomplete Permissions window responds to a permission grant without a second request, that closing it stops waiting, and that reopening resumes the saved step. At Keyboards, assign an Input Source, use Back from Ready, and check that the assignment remains. An included, unrenamed keyboard should show only `Connected` or `Disconnected` below its name; an ignored keyboard should append ` (Ignored)` to its connection status, with the original product name and ` - ` prefix only when it has a custom name. Use an external keyboard's trailing menu to Ignore it: it should stay in place with its saved Input Source disabled, and its status should follow physical connect and disconnect events. Reopen setup, Rename… the ignored keyboard, and confirm its assignment remains visible; then Stop ignoring it and check its name and assignment. The built-in keyboard must have no menu action, and a persistence error must disable changes. Check the menu labels and order with VoiceOver. Both Continue and Set Up Later should reach Ready with zero assignments. Finish should close the window while the menu bar app stays available; Open Settings should close it and show Settings. When switching is paused, permission is revoked, or switching is unavailable, Ready should show the corresponding warning.

Use the named previews in `Sources/Features/Onboarding/OnboardingView.swift` to compare the three stages in light and dark appearances, including empty assignments, unavailable sources, exclusions, permission recovery, and persistence failures. Check the 840 × 640 previews: long content must scroll while the footer remains reachable. The fixture stores are isolated from saved user data. A live Input Monitoring grant still needs a manual check in System Settings.

### Settings

Run `./Scripts/run.sh test` after changes to the Settings panes, the shared keyboard row, or the Settings window. Open Settings from the menu bar and from the end of Guided setup, and check that reopening it returns to the pane that was showing. The three panes are General, Keyboards, and About in that order.

General should show the `App` heading, the Launch at login switch with its explanation, and the menu-bar line. Turning the switch on and off must persist across a relaunch; a failed change must keep the switch at the real service state and add the Login Items guidance.

Keyboards should show one row per Physical Keyboard, with the ignored ones in place and dimmed: name and connection status, the Input Source picker, and the trailing menu. Rename… an external keyboard and confirm the name and the `product - Connected` status; Ignore it and confirm the picker is disabled, the status appends ` (Ignored)`, and the row stays where it was; Stop ignoring it and confirm its name and assignment return. The built-in keyboard must show no actions menu, and a persistence error must disable the picker and the menu while the notice with Retry stays visible. With no keyboards connected, the pane shows `No keyboards detected` and the connection guidance.

About should show the app icon, name, and tagline, the information rows, the Sparkle acknowledgement, and the creator credit. Version must match the running build. `View on GitHub` and `@fedemas` must open the browser; `Open in Finder` must create and open the two folders; the license rows must open the bundled `LICENSE.txt` and `Sparkle-LICENSE.txt`; `Check for Updates…` must be disabled while Sparkle cannot check.

Use the named previews in `Sources/Features/Configuration/SettingsView.swift` to compare all three panes and the Keyboards empty state in light and dark appearances, and at 840 × 560 with large text and many keyboards. Compare them against the Pencil `Settings / General`, `Settings / Keyboards`, `Settings / About`, and `Settings / Keyboards / Empty` frames. Check keyboard navigation and VoiceOver: the sidebar items must report their selected state, and each keyboard row must read its name, status, Input Source, and menu.

## Verify the native menu-bar menu

1. Open the status item in light and dark appearance. Confirm the native heading shows `Keyameleon v<marketing version>`, there is no version footer row, and Quit Keyameleon is last. Confirm the heading, Keyboards heading, and commands use native menu rows, with no About Keyameleon row. Confirm the application menu also has no About Keyameleon command. Hover the heading, notices, commands, and keyboard warning symbol; no tooltip should appear. The middle region shows either custom keyboard pills or one custom notice, never both. Assigned keyboards keep saved order. The menu keeps its usual width when a notice has a long title or explanation.
2. Check active, built-in, disconnected, and unavailable-source keyboards. Confirm each pill is one line: the symbol, the name (custom name when set, the product name otherwise), the filled locale-code badge, and the dimmed treatment for a disconnected keyboard, which leaves the warning triangle undimmed. Confirm the full VoiceOver names. With six assignments and larger text, scroll the five-row keyboard viewport to the last row.
3. Choose Pause Switching (Command-P), then reopen the menu. Confirm `(Paused)` and Resume Switching. Choose Resume and reopen. Every selected command, including Retry and Request Permission, closes normally.
4. Use Command-comma for Settings. Confirm Check for Updates… sits directly below Settings, has no shortcut or tooltip, and is disabled before the updater is ready. When ready, select it and confirm it becomes disabled while checking. After the check finishes, reopen the menu and confirm it is enabled again. On a disposable session, use Command-Q for Quit. Use arrow keys and Return to move through native commands; Escape, an outside click, or a status-item click dismisses the menu without changing switching state.
5. Deny Input Monitoring. Confirm the yellow notice replaces the Keyboards heading and list, with its full explanation and a full-width Open System Settings button when available, or Request Permission when that is the available action. Click Open System Settings and confirm the menu closes and System Settings opens to Input Monitoring. Click the available Request Permission fallback and confirm the menu closes before requesting access. If neither recovery action is available, the button opens Settings. Check neutral temporarily unavailable, mismatch, and selection-failure notices. Their full-width button opens Settings, except selection failure offers Retry Now when available.
6. Check no assignments, unfinished Guided Setup, and saved-data failure. Each notice replaces the entire keyboard region. Unassigned keyboards offer Open Settings, and unfinished setup offers Continue Guided Setup. A yellow saved-data failure notice takes precedence over switching notices and offers Retry. Persistence Retry is distinct from switching Retry Now. Use arrow keys to select the notice and Return to activate its action; verify saved-data Retry without clicking the button. If recovery reveals a permission notice, repeat keyboard activation and verify it opens System Settings. Resolve a notice and confirm the keyboard region returns.
7. Enable Increase Contrast and Reduce Transparency. Confirm the native background stays readable and the existing keyboard contrast treatment remains visible. While the menu is open, scroll a six-keyboard list, then change a keyboard or recovery state. Confirm ordinary keyboard updates preserve the scroll position. A transition to a notice replaces the list, and resolving it restores the list. Confirm each notice remains readable and its CTA enabled state is respected.

`MenuBarPanelPreviews.swift` previews the custom keyboard region. `MenuBarPanelNoticeView.swift` previews warning, neutral, and long notices in light and dark appearances. Verify complete native menu behavior in the running app.
