# Manual verification: Guided setup and Settings

Checklists for [Manual verification](../testing.md#manual-verification).

## Guided setup

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

## Settings

**Window and navigation**

- Open Settings from the menu bar, from the end of Guided setup, and with ⌘, while Keyameleon is active. Every path shows the same single window. Reopening returns to the last pane. Toolbar items are General, Keyboards, Apps, and About, in that order.
- Select each toolbar item. The item highlights, the pane changes, and the window title becomes the pane name, in active and inactive windows. VoiceOver reads each toolbar item and its selected state.
- The window cannot be resized; its content stays 620 × 500.
- All panes share one spacing policy: the same left edge for section headers and rows, native row insets, and the same outer margin. At 620 × 500, the Keyboards empty and persistence-failure states line up with the populated list's header.

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

- Shows the information rows, Sparkle acknowledgement, and creator credit, with no app icon or name above them. The credit scrolls into view.
- Version matches the running build.
- `View on GitHub` and `@fedemas` open the browser. `Open in Finder` creates and opens both folders, whose paths stay selectable. The license rows open the bundled `LICENSE.txt` and `Sparkle-LICENSE.txt`. `Check for Updates…` is disabled while Sparkle cannot check.
- Larger text does not clip toolbar labels or folder paths.

**Previews.** The named previews in `Sources/Features/Configuration/SettingsView.swift` cover all three panes and the empty Keyboards state in light and dark, and at 620 × 500 with large text and many keyboards. The toolbar is native, so previews show only the pane. Compare the panes with the Pencil frames `Settings / General`, `Settings / Keyboards`, `Settings / About`, and `Settings / Keyboards / Empty` in `design/design.pen`.
