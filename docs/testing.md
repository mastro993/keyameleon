# Testing

## Run the tests

```sh
./Scripts/run.sh test
```

This runs the safety audit, SwiftLint, the Python script tests, and then the Swift Testing and XCTest bundles, one after the other, on macOS 26. Afterwards it stops any leftover Keyameleon process whose executable is the Debug app or the test host under `./build`, and unregisters the test host from LaunchServices so Quit & Reopen cannot open it.

Hosted tests launch Keyameleon itself, so **quit any running Keyameleon first**; otherwise the test host exits under the single-instance lock. Tests use ad hoc signing, need no certificate, and build into `./build/test`, so they never replace the signed app from `run.sh open`. The test host runs under the Debug identity, `dev.fedemas.keyameleon.debug` ([ADR 0008](adr/0008-separate-debug-identity.md)). See [Development](development.md) for setup and SwiftLint policy.

## What to test

- Each test protects one distinct user-visible outcome or one critical safety rule.
- Prefer Swift Testing in `Tests/SwiftTesting` for domain and model seams. Use XCTest in `Tests/XCTest` only for AppKit shell contracts. There is no UI-test target.
- Do not test private counters or implementation wiring.
- Do not add repeated suites, fixed event counts, participant quotas, qualification evidence files, endurance runs, or performance thresholds unless a real product failure needs them ([ADR 0001](adr/0001-product-validation.md)).

These rules are hard failures:

- Keyameleon stays monitor-only: it never injects or changes Physical Keyboard Events.
- Key Content never enters saved data, log files, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

### Test environment rules

- Hosted test processes (`KeyameleonSwiftTesting`, `KeyameleonXCTest`) must not start CoreHID observation, the lifecycle observer, the status item, Guided setup, or Sparkle. Detect them with `XCTestConfigurationFilePath` or `XCTestBundlePath` ([ADR 0005](adr/0005-hosted-unit-tests-skip-live-surface.md)).
- Tests run in English and the U.S. region: the scheme's test action sets both, so copy assertions hold whatever language the Mac uses. Translations are checked by `Tests/Scripts/test_localization.py` and `LocalizationTests.swift`.
- Hosted app startup and Xcode previews use in-memory SwiftData storage. Store relocation and persistence-failure tests use disposable directories and never touch the user's real data.
- Saved Physical Keyboard changes are tested through `SavedPhysicalKeyboardChanges` with the real SwiftData adapters: rollback, exact Retry, blocked competing changes, and notifications after commit for rename and assignment. Model tests cover the displayed failure and recovery. `ManualDesignationTests` seeds designations the way earlier versions saved them and checks that authentic evidence is honored and tampered evidence is not.

## Continuous integration

The `CI` workflow reports one required check, **Required CI gate**, on every pull request and every push to `main`:

- **Build-affecting changes** run `./Scripts/run.sh test` on a `macos-26` runner. These include `Sources`, `Resources`, `Keyameleon-icon.icon`, `LICENSE` and `THIRD_PARTY_NOTICES.md` (they are bundled in the app), `Tests`, `Scripts`, `project.yml`, the Xcode project and package files, `.swiftlint.yml`, and both workflow files. The `Check whether code changed` step in [`ci.yml`](../.github/workflows/ci.yml) holds the exact list.
- **Everything else**, such as documentation, skips the macOS job and passes.

The macOS job has an eight-minute limit and no automatic retry; a maintainer reruns infrastructure failures after inspection. The `main` ruleset requires **Required CI gate**. Do not require the conditional `Build and test` job instead: a skipped job can satisfy a required check even when the gate fails.

## Manual verification

Unit tests cannot prove real permission grants, native menu tracking, display placement, or VoiceOver. After changing one of the areas below, run `./Scripts/run.sh test`, then work through its checklist in the running app (`./Scripts/run.sh open`).

### Input Monitoring persistence

Do not use the ad hoc test build for this.

1. Build with Xcode Run or `run.sh open`, grant Input Monitoring to that Debug build in System Settings, then quit and reopen it.
2. Rebuild and run again. The permission must stay granted and no prompt may return.

A grant made to an earlier ad hoc build may need replacing once for the newly signed app.

### Guided setup

**Permissions**

- An incomplete Permissions step responds to a grant without a second request.
- Before macOS has asked, the footer offers Allow Input Monitoring; afterward, Open System Settings and Restart Keyameleon.
- Before setup completes there is no menu bar icon, and typing on an assigned keyboard does not change the Input Source.
- Closing the window quits Keyameleon. Opening it again resumes the saved step.
- Finish shows the menu bar icon, and switching starts.

**Keyboards**

- Assign an Input Source, go to Ready, use Back, and check that the assignment remains.
- An included keyboard without a custom name shows only `Connected` or `Disconnected` below its name. With a custom name, the status is prefixed by the product name and a middle dot (`·`). An ignored keyboard appends ` (Ignored)`.
- Ignore an external keyboard from its trailing menu: it stays in place with its saved Input Source disabled, and its status follows physical connect and disconnect.
- Reopen setup, Rename… the ignored keyboard, and confirm its assignment is still shown. Stop Ignoring it and check its name and assignment.
- The built-in keyboard has no menu actions. A persistence error disables changes.
- Check the menu labels and order with VoiceOver.
- With many keyboards, scroll through the last row and the switching note. Progress, explanation, rows, and note share one scrolling region, and the footer stays visible. Repeat with larger text and dark appearance: the footer grows without clipping its controls.

**Ready**

- Both Continue and Set Up Later reach Ready with zero assignments.
- Finish closes the window and the menu bar app stays available. Open Settings closes setup and shows Settings.
- When switching is paused, permission is revoked, or switching is unavailable, Ready shows the matching warning.

**Previews.** The named previews in `Sources/Features/Onboarding/OnboardingView.swift` cover all three stages in light and dark: empty assignments, unavailable sources, exclusions, permission recovery, and persistence failures. At 840 × 640, long content scrolls while the footer stays reachable. Compare the sidebar artwork, colors, and layout across Permissions, Keyboards, and Ready.

### Settings

**Window and navigation**

- Open Settings from the menu bar and from the end of Guided setup. Reopening returns to the last pane. Panes are General, Keyboards, Apps, and About, in that order.
- Select each sidebar row, then move between panes with the arrow keys. Check the blue selection, filled icon, keycap identity, and sidebar surface in active and inactive windows. Sidebar items report their selected state to VoiceOver.
- The window does not shrink below 840 × 560.
- All panes share one spacing policy: the same left edge for section headers and rows, native row insets, and the same outer margin. At 840 × 560, the Keyboards empty and persistence-failure states line up with the populated list's header.

**General**

- Shows the `App` heading and the Launch at login switch, then the `Switching` heading with the **When input source changes externally** picker and its full-width description, set to `Switch back` on a fresh install or after updating.
- Toggling Launch at login persists across a relaunch. A failed change leaves the switch at the real service state and shows an error with Open Login Items.
- The choice persists across a relaunch.

**Keyboards**

- One row per Physical Keyboard, ignored ones in place and dimmed: name, connection status, Input Source picker, and trailing menu.
- Rename… an external keyboard: the name changes and the status reads `<product> · Connected`.
- Ignore it: the picker is disabled, the status appends ` (Ignored)`, and the row stays in place. Ignored rows mute their name, status, and picker text while Stop Ignoring stays usable. Stop Ignoring restores its name and assignment.
- The built-in keyboard has no actions menu.
- A persistence error disables the picker and menu while the notice with Retry stays visible, and the empty state is hidden.
- With no keyboards, the pane shows the native `No keyboards detected` state and connection guidance.
- VoiceOver reads each row's name, status, Input Source, and menu.

**Keyboard order and assignments** (Guided setup and Settings)

- The built-in keyboard is first, even when it is discovered after external or ignored rows. Other rows keep their relative order and identity.
- An editable picker with no assignment, and an ignored keyboard's disabled picker with no saved assignment, both show `Unassigned`.
- Missing or ambiguous saved records show a disabled `Unassigned` picker, never `Assignment unavailable` or an assignment borrowed from another record.

**Apps**

- With no App Assignments, the pane shows `No apps` with Add App….
- Add App… lists running Dock apps by name with their icons, never Keyameleon or an app already listed, then Choose Other App…, which opens at `/Applications`. A new row starts on the current Input Source.
- Change a row's Input Source: there is no `Unassigned` choice. Remove it from the trailing menu.
- Assign an app, then uninstall or rename its bundle identifier away: the row stays with a placeholder icon and `Not installed`.
- Remove an assigned Input Source from macOS: the row reads `Unavailable`.
- VoiceOver reads each row's name, Input Source, and menu.

**About**

- Shows the app icon, name, tagline, information rows, Sparkle acknowledgement, and creator credit. The identity sits on the pane background and the credit scrolls into view.
- Version matches the running build.
- `View on GitHub` and `@fedemas` open the browser. `Open in Finder` creates and opens both folders, whose paths stay selectable. The license rows open the bundled `LICENSE.txt` and `Sparkle-LICENSE.txt`. `Check for Updates…` is disabled while Sparkle cannot check.
- Larger text does not clip sidebar labels or folder paths.

**Previews.** The named previews in `Sources/Features/Configuration/SettingsView.swift` cover all three panes and the empty Keyboards state in light and dark, and at 840 × 560 with large text and many keyboards. Compare them with the Pencil frames `Settings / General`, `Settings / Keyboards`, `Settings / About`, and `Settings / Keyboards / Empty` in `design/design.pen`.

### Menu bar menu

1. **Structure.** Open the menu in light and dark. The heading reads `Keyameleon v<marketing version>`, there is no version footer, no Keyboards label, and no About Keyameleon row (nor in the application menu). Quit Keyameleon is last. No row shows a tooltip on hover. The middle region shows either keyboard pills or one notice, never both. The menu keeps its width when a notice has long text.
2. **Keyboards.** Check active, built-in, disconnected, and unavailable-source keyboards. The list keeps a 4 pt inset from the edges. Each pill is one line: symbol, name (custom name, or product name), and the filled locale-code badge. Disconnected pills are dimmed, except the warning triangle. Only assigned keyboards appear: the built-in keyboard first, then connected, then disconnected ones, alphabetical by name within each group. Check the full VoiceOver names. With six assignments and larger text, scroll the five-row viewport to the last row.
3. **Pause.** Choose Pause Switching (<kbd>⌘</kbd><kbd>P</kbd>) and reopen: the heading shows `(Paused)` and the command reads Resume Switching. Resume and reopen. Every command, including Retry, Allow Input Monitoring, and Restart Keyameleon, closes the menu.
4. **Commands.** <kbd>⌘</kbd><kbd>,</kbd> opens Settings. Check for Updates… sits directly below Settings with no shortcut or tooltip, and is disabled until the updater is ready and while a check runs; reopen after the check to see it enabled again. On a disposable session, <kbd>⌘</kbd><kbd>Q</kbd> quits. Arrow keys and Return move through commands. Escape, an outside click, or a status item click dismisses the menu without changing switching state.
5. **Permission notice.** With the decision unknown, a yellow Input Monitoring required notice replaces the keyboard list and its button, Allow Input Monitoring…, closes the menu and shows the macOS alert. With the switch off, the notice reads Input Monitoring is off, its button opens Input Monitoring, and Restart Keyameleon appears below Pause Switching.
6. **Other notices.** Temporarily unavailable, mismatch, and unassigned notices are neutral and open Settings; selection failure offers Retry Now when available. A yellow saved-data failure notice outranks switching notices and offers Retry, which is separate from switching's Retry Now. Select a notice with the arrow keys and activate it with Return, including saved-data Retry. If recovery reveals a permission notice, activate it from the keyboard and check that System Settings opens. Resolving a notice brings the keyboard list back.
7. **Accessibility.** With Increase Contrast and Reduce Transparency on, the background stays readable and the keyboard contrast treatment stays visible. With the menu open, scroll a six-keyboard list and change a keyboard or recovery state: ordinary updates keep the scroll position, and a notice replaces the list until resolved. With Reduce Motion on, changing the active keyboard updates the pill without its spring. Links and buttons show their native pointer without a stuck hand cursor.
8. **Same Input Source on two keyboards.** With U.S. selected, assign it to two keyboards. Press a key on the first, the second, then the first again, reopening the menu each time. Only the last-used keyboard shows the active accent while U.S. stays selected. `menuBarPanelActivatesKeyboardWithCurrentInputSource` automates this sequence.

9. **App Assignments.** With Terminal assigned to U.S. and frontmost, the first pill is Terminal with its icon, the U.S. badge, and the accent; the active keyboard's pill has no accent. Switch to an unassigned app: the Terminal pill disappears and the keyboard's accent returns. An unavailable App Assignment shows the warning triangle on the Terminal pill and the warning menu bar icon. Changing the Input Source in Terminal shows the mismatch notice naming Terminal.
10. **Input Source Hold.** During a hold (see [External Input Source Changes](#external-input-source-changes)), the menu shows a neutral `Input source kept` notice naming the current Input Source and what ends the hold, instead of the mismatch notice. **Switch Back Now** closes the menu, ends the hold, and selects the Active Physical Keyboard's Input Source; reopening shows the keyboard list.

`MenuBarPanelPreviews.swift` previews the keyboard region, and `MenuBarPanelNoticeView.swift` previews warning, neutral, and long notices in light and dark. Verify native menu behavior in the running app.

### External Input Source Changes

`InputSourceHoldPolicyTests` covers every start and end rule, and `InputSourceHoldTests` drives them through the module seams. Check the real behavior with two assigned keyboards, A on U.S. and B on Italian, and a third Input Source such as French enabled. Type on A first so it is the Active Physical Keyboard. Change the Input Source with the menu bar, a shortcut, and the Globe key; all three behave the same. The Log File shows one `debug` line when a hold starts and one when it ends, with the reason.

1. **Switch back.** Change to French. The next key press on A selects U.S. again. No hold notice appears.
2. **Keep until another keyboard.** Change to French. Keep typing on A: French stays, and the menu shows the hold notice. Type on B: Italian is selected. Repeat, and type on an unassigned keyboard instead: French stays and the hold ends; typing on A then selects U.S.
3. **Keep until matching keyboard.** Change to Italian while typing on A: Italian stays while you type on A. Type on B: the hold ends without a visible change. Type on A: U.S. is selected. With a Japanese input method assigned to A, toggling Kana and Eisu while typing on A keeps the hold until you type on a keyboard assigned to the mode now selected.
4. **Fresh launch.** Relaunch, change to French before typing, then type on B: French stays. Type on A: U.S. is selected.
5. **Hold ends.** Start a hold, then check each ending separately: Switch Back Now in the menu (selects A's Input Source), Pause then Resume, changing the picker in General, editing or removing the holding keyboard's Input Source in Keyboards, disconnecting the holding keyboard, and relaunching. After each, the next key press on A selects U.S.
6. **Hold survives.** Start a hold, sleep and wake the Mac, then type on A: French stays. Typing on an ignored device never ends a hold.
7. **No hold.** Change to A's own Input Source while A is active, or change it while paused or during Guided setup: no hold notice appears.

### App Assignments

`AppAssignmentSwitchingTests` covers the rules through the module seams. Check the real behavior with keyboard A on Italian, Terminal assigned to U.S., and macOS per-document switching off.

1. **Override.** Type on A in TextEdit: Italian. Switch to Terminal: U.S. is selected before you type. Type on A: U.S. stays.
2. **Leave.** Switch from Terminal to TextEdit: Italian is selected right away.
3. **No keyboard yet.** Relaunch Keyameleon with Terminal in front, then switch away and back: U.S. is selected without typing.
4. **Settings.** Open Settings › Apps from Terminal and change Terminal to French: the Input Source does not change while Settings is in front. Return to Terminal and type: French is selected.
5. **Hold.** Set **Keep until another keyboard**, type on A in TextEdit, and change to French: French stays. Switch to Terminal: the hold ends and U.S. is selected.
6. **Pause.** Pause switching and switch to Terminal: nothing changes.
7. **Log.** The Log File names the app on selections it caused, and has no line for switching to an unassigned app.

### Input Monitoring recovery

`InputMonitoringRecoveryTests` covers the actions per decision, the Settings deep link, the relaunch guard, the one-time stale reset, and that a manual launch never resets with injected side effects, so tests never open System Settings, run `tccutil`, or quit. `SetupModelTests` covers a grant advancing setup through the permission watch. Check the real behavior on macOS 26 with the Debug identity, never the installed release's: every reset below removes only the row for `dev.fedemas.keyameleon.debug` ([ADR 0008](adr/0008-separate-debug-identity.md)). Afterwards, quit the Debug app and open the installed release: it must still read Input Monitoring as granted.

1. **Unknown.** Run `tccutil reset ListenEvent dev.fedemas.keyameleon.debug`, then open the Debug app with `./Scripts/run.sh open`. Guided setup and the menu notice offer only Allow Input Monitoring. Choosing it shows the macOS alert, Keyameleon appears switched off in Input Monitoring, and the UI switches to Open System Settings with Restart Keyameleon.
2. **Grant.** Choose Open System Settings: Input Monitoring opens, including when System Settings is already open on another pane. Turn Keyameleon on and choose Quit & Reopen: Keyameleon reopens Ready, and Guided setup continues at Keyboards.
3. **Later.** Repeat with Later instead. If the status does not recover within a few seconds, Restart Keyameleon reopens it Ready.
4. **Stale row.** With the switch on for the signed Debug app, quit it and open the ad hoc test app that `./Scripts/run.sh test` built, `build/test/Build/Products/Debug/Keyameleon (Dev).app`. It has the same Debug bundle identifier but a different signature, so it reads Input Monitoring is off. Choose Restart Keyameleon: after reopening, the macOS alert appears and Keyameleon is listed switched off. Turn it on, choose Later, then Restart Keyameleon: Ready. Restart Keyameleon reopens this copy by path, while Quit & Reopen could open the signed copy instead. To give the row back to the signed app, quit the test app, run `./Scripts/run.sh open`, and repeat the same steps.
5. Quit Keyameleon normally and reopen: nothing is reset and no alert appears.
