# Manual verification: menu and switching

Checklists for [Manual verification](../testing.md#manual-verification).

## Menu bar menu

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

## External Input Source Changes

`InputSourceHoldPolicyTests` covers every start and end rule, and `InputSourceHoldTests` drives them through the module seams. Check the real behavior with two assigned keyboards, A on U.S. and B on Italian, and a third Input Source such as French enabled. Type on A first so it is the Active Physical Keyboard. Change the Input Source with the menu bar, a shortcut, and the Globe key; all three behave the same. The Log File shows one `debug` line when a hold starts and one when it ends, with the reason.

1. **Switch back.** Change to French. The next key press on A selects U.S. again. No hold notice appears.
2. **Keep until another keyboard.** Change to French. Keep typing on A: French stays, and the menu shows the hold notice. Type on B: Italian is selected. Repeat, and type on an unassigned keyboard instead: French stays and the hold ends; typing on A then selects U.S.
3. **Keep until matching keyboard.** Change to Italian while typing on A: Italian stays while you type on A. Type on B: the hold ends without a visible change. Type on A: U.S. is selected. With a Japanese input method assigned to A, toggling Kana and Eisu while typing on A keeps the hold until you type on a keyboard assigned to the mode now selected.
4. **Fresh launch.** Relaunch, change to French before typing, then type on B: French stays. Type on A: U.S. is selected.
5. **Hold ends.** Start a hold, then check each ending separately: Switch Back Now in the menu (selects A's Input Source), Pause then Resume, changing the picker in General, editing or removing the holding keyboard's Input Source in Keyboards, disconnecting the holding keyboard, and relaunching. After each, the next key press on A selects U.S.
6. **Hold survives.** Start a hold, sleep and wake the Mac, then type on A: French stays. Typing on an ignored device never ends a hold.
7. **No hold.** Change to A's own Input Source while A is active, or change it while paused or during Guided setup: no hold notice appears.

## App Assignments

`AppAssignmentSwitchingTests` covers the rules through the module seams. Check the real behavior with keyboard A on Italian, Terminal assigned to U.S., and macOS per-document switching off.

1. **Override.** Type on A in TextEdit: Italian. Switch to Terminal: U.S. is selected before you type. Type on A: U.S. stays.
2. **Leave.** Switch from Terminal to TextEdit: Italian is selected right away.
3. **No keyboard yet.** Relaunch Keyameleon with Terminal in front, then switch away and back: U.S. is selected without typing.
4. **Settings.** Open Settings › Apps from Terminal and change Terminal to French: the Input Source does not change while Settings is in front. Return to Terminal and type: French is selected.
5. **Hold.** Set **Keep until another keyboard**, type on A in TextEdit, and change to French: French stays. Switch to Terminal: the hold ends and U.S. is selected.
6. **Pause.** Pause switching and switch to Terminal: nothing changes.
7. **Log.** The Log File names the app on selections it caused, and has no line for switching to an unassigned app.

## Automation

`AutomationCommandTests` covers URL parsing and each action, `AutomationSelectionTests` checks that a selection is an External Input Source Change, and `ApplicationAutomationTests` checks a URL that launches Keyameleon. Check the real behavior in the Debug app with `keyameleon-dev://` and keyboard A on U.S.

1. **URLs.** Run `open keyameleon-dev://pause`: the menu heading shows `(Paused)`. `toggle-pause` resumes it, `resume` leaves it running. `open keyameleon-dev://unknown` changes nothing and writes one `warning` line to the Log File. So does `select-input-source?name=Greek` when Greek is not enabled. `select-input-source?id=US` selects U.S. whatever language Keyameleon uses, and `?name=` takes the name in Keyameleon's language (`USA` in Italian). `open 'keyameleon-dev://set-external-change-response?value=hold-until-keyboard-change'` changes the General settings picker to Keep until another keyboard, also while Settings is open, and ends any hold.
2. **Select.** With Switch Back, run `open 'keyameleon-dev://select-input-source?id=Italian'`: Italian is selected, and the next key press on A selects U.S. With Keep until another keyboard, Italian stays while you type on A and the menu shows the hold notice. Quit Keyameleon, select U.S. from the macOS menu bar, and run the URL again: it launches without a window, selects Italian, and shows the hold notice. Without changing to U.S. first, Italian is already current, so the URL changes nothing and no hold starts. While paused, the URL selects Italian, starts no hold, and the menu names Italian.
3. **Shortcuts.** In the Shortcuts app, the five Keyameleon actions appear in your language. Select Input Source lists only enabled keyboard layouts. Get Active Keyboard and Input Source returns A's name and the current Input Source after you type on A. Pause, change the Input Source from the macOS menu bar, and run it again: it returns the new Input Source. Quit Keyameleon and run a Pause shortcut: Keyameleon launches without a window and pauses.
