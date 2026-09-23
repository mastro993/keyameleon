# Plan 001: The menu-bar panel explains Switching Status and offers one recovery action

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c3a172f..HEAD -- Sources/Features/Menu/MenuBarPanelContent.swift Sources/Features/Menu/MenuBarPanelView.swift Sources/Features/Menu/MenuBarPanelAccessibility.swift Sources/Features/Menu/MenuBarActionList.swift Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift Tests/SwiftTesting/Features/Menu/MenuBarPanelAccessibilityTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `c3a172f`, 2026-09-22

## Why this matters

The menu-bar icon already changes for Permission Required, Temporarily Unavailable, Paused, a current-versus-assigned Input Source mismatch, an unassigned Physical Keyboard, an Unavailable Keyboard Assignment, and unfinished Guided setup. The open panel does not say why. Its footer is always Pause or Resume, Settings, and Quit, even when Activity-Triggered Switching has already published `requestPermission` or `retryNow`.

A person who sees the warning icon opens the panel and still has nothing to read and nothing to press. This plan adds one notice, and at most one button, using facts the outcome already has. It does not bring back the old status dump, and it does not edit Keyboard Assignments inside the panel.

## Current state

Vocabulary from `CONTEXT.md`. Use these terms in new copy. Do not invent synonyms.

- **Switching Status**: Ready, Permission Required, Paused, or Temporarily Unavailable.
- **Activity-Triggered Switching**: selects a Keyboard Assignment after Activation Activity. The Physical Keyboard Event that causes the change can still use the previous Input Source. Avoid the phrases "first-key guarantee", "next-key guarantee", and "best-effort switching".
- **Keyboard Assignment**, **Input Source**, **Physical Keyboard**, **Active Physical Keyboard**, **Unavailable Keyboard Assignment**.

`Sources/Features/Menu/MenuBarPanelContent.swift` builds the panel model. `makeActions` ignores recovery actions:

```swift
private static func makeActions(
    outcome: ActivityTriggeredSwitchingOutcome
) -> [Action] {
    [
        pauseOrResume(outcome: outcome),
        Action(id: .settings, title: "Settings", isEnabled: true, closesPanel: true),
        Action(id: .quit, title: "Quit Keyameleon", isEnabled: true, closesPanel: true),
    ]
}
```

`MenuBarPanelActionID` already has `requestPermission`, `openSystemSettings`, and `checkAgain`. It has no `retryNow`. `Sources/Features/Menu/MenuBarPanelView.swift` `perform` already calls `setupModel.requestPermission()`, `setupModel.openSystemSettings()`, and `switching.checkAgain()` for those ids. It has no `retryNow` branch. `switching.retryNow()` exists on `ActivityTriggeredSwitching`.

`Sources/Features/Menu/MenuBarPanelView.swift` lays the panel out as header, divider, assignment section, action list. Width is `MenuBarPanelContent.panelWidth` (280). The view builds content in `makeContent()` and does not pass `setupModel.isSetupComplete`.

`Sources/Features/Menu/MenuBarPanelAccessibility.swift` speaks the panel label "Keyameleon" with value `content.switchingStatus.rawValue`. Keyboard order is About, assignment rows, then footer actions. There is no notice.

`Sources/Features/Menu/MenuBarAssignmentList.swift` lists only Physical Keyboards that already have a Keyboard Assignment (`keyboardAssignment != nil`). An unassigned Physical Keyboard is absent from the list. An Unavailable Keyboard Assignment stays in the list as "Unavailable Input Source" plus the note "Unavailable Keyboard Assignment".

`Sources/Features/Menu/ApplicationDelegate+Menu.swift` turns the icon to the warning mark when Switching Status is Ready and any of these is true: `setupModel.physicalKeyboardActionConditions` is non-empty, Guided setup is incomplete, or `outcome.mismatch != nil`. Do not change that icon rule in this plan.

`ActivityTriggeredSwitchingOutcome` already carries `switchingStatus`, `temporarilyUnavailableReasons`, `activePhysicalKeyboard`, `mismatch` (`currentName`, `assignedName`), `warnings` (`physicalKeyboardName`, `category`, `recoveryAction`), and `availableActions`. `SwitchingFailureCategory.selectionFailed` pairs with `SwitchingRecoveryAction.retryNow`.

Tests in `Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift` lock the footer: Permission Required still has footer ids `[.pause, .settings, .quit]`, and "Recovery actions never appear in the menu" asserts those footer titles. Keep the footer contract. Put the new button on the notice, not in the footer.

`Tests/SwiftTesting/Features/Menu/MenuBarPanelAccessibilityTests.swift` test `menuBarPanelKeyboardFocusOrderVisitsAssignmentsThenActions` expects this order for a Permission Required fixture with two assignments:

```swift
.about,
.assignment(id: "desk"),
.assignment(id: "travel"),
.action(id: .pause),
.action(id: .settings),
.action(id: .quit)
```

The same file's ready-panel VoiceOver test expects labels `Keyameleon`, `About Keyameleon`, `Travel`, `Pause`, `Settings`, `Quit Keyameleon`. A Ready panel with no notice must keep that order.

Conventions to match:

- One primary type per Swift file. See `Sources/Features/Menu/MenuBarAssignmentList.swift`.
- User-facing copy lives on the type that shows it. There is no string catalog.
- Views that own focus use `@MainActor`, as `KeyameleonMenuBarPanelView` does.
- Use `foregroundStyle`, not `foregroundColor`. Use `Button`, not `onTapGesture`. Match the empty-state title style `.font(.body.weight(.medium))` and secondary detail style `.font(.callout)`.
- The safety audit fails the build if Sources contain `CGSize` (the pattern is `CGS[A-Za-z]`), `print(`, `NSLog`, or `URLSession`. Do not use those.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS` is on. A new `switch` on `MenuBarPanelActionID` must be exhaustive.
- Tests are Swift Testing functions with `@Test("...")` and `@MainActor` when they touch main-actor types. Model them on `Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift`. There is no UI-test target.
- New non-private `View` structs need a named preview in the same file: `#Preview("...")`. `Tests/Scripts/test_preview_coverage.py` enforces this. Wrap previews in `#if DEBUG`, as `MenuBarPanelView.swift` does.
- `project.yml` lists `Sources` and `Tests/SwiftTesting` as folders, but `Keyameleon.xcodeproj/project.pbxproj` enumerates files. A new Swift file is invisible to `xcodebuild` until `./Scripts/run.sh generate`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Regenerate the Xcode project after adding Swift files | `./Scripts/run.sh generate` | exit 0 |
| Preview coverage | `python3 -m unittest Tests/Scripts/test_preview_coverage.py` | `OK` |
| Safety audit | `./Scripts/run.sh audit` | exit 0 |
| Product tests | `./Scripts/run.sh test` | exit 0. This runs the audit, Python tests, then both hosted test bundles |

`./Scripts/run.sh test` needs Xcode on this Mac and writes under `./build`. Do not pass extra arguments. If `xcodegen` is not on `PATH`, STOP. Do not install it.

## Scope

**In scope**:

- `Sources/Features/Menu/MenuBarPanelNotice.swift` (create)
- `Sources/Features/Menu/MenuBarPanelNoticeView.swift` (create)
- `Sources/Features/Menu/MenuBarPanelContent.swift`
- `Sources/Features/Menu/MenuBarPanelView.swift`
- `Sources/Features/Menu/MenuBarPanelAccessibility.swift`
- `Sources/Features/Menu/MenuBarActionList.swift`
- `Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift`
- `Tests/SwiftTesting/Features/Menu/MenuBarPanelAccessibilityTests.swift`
- `Keyameleon.xcodeproj/` changes produced by `./Scripts/run.sh generate`
- `plans/README.md` status row for 001

**Out of scope**:

- `ActivityTriggeredSwitching.swift` and every other file under `Sources/Features/ActivityTriggeredSwitching/`. Do not change when an Input Source is selected.
- `ApplicationDelegate+Menu.swift` and `MenuBarIconMark`. The icon rule stays.
- `MenuBarAssignmentList.swift`. Rows stay read-only and assigned-only.
- Footer action ids. Do not add Request Permission, Check Again, Open System Settings, or Retry Now to the footer.
- Guided setup copy (`OnboardingView.swift`). That is plan 003.
- Settings windows, operational notification text, and the README screenshot.
- Do not add `checkAgain` or `openSystemSettings` buttons anywhere. `SetupModel.requestPermission()` already opens System Settings when permission stays denied.

## Git workflow

- Branch from current `HEAD`: `advisor/001-menu-bar-status-notice`
- One commit at the end, after `./Scripts/run.sh test` exits 0: `feat(panel): explain Switching Status in the menu bar`
- Do not push or open a pull request.
- Do not rebase onto `main` as part of this plan.

## Steps

### Step 1: Add the notice model

Create `Sources/Features/Menu/MenuBarPanelNotice.swift` with one struct, `MenuBarPanelNotice: Equatable, Sendable`, holding `title: String`, `detail: String`, and `action: MenuBarPanelContent.Action?`.

Add `static func make(outcome:physicalKeyboards:isSetupComplete:) -> MenuBarPanelNotice?`. Return the first match below. Do not combine two notices.

1. **Permission Required.** Title `Permission Required`. Detail `Keyameleon needs Input Monitoring to observe Activation Activity.` Action is Request Permission only when `outcome.hasAction(.requestPermission)`. The action id is `.requestPermission`, `isEnabled: true`, `closesPanel: false`.
2. **Temporarily Unavailable.** Title `Temporarily Unavailable`. Action is nil. Detail is the first matching reason sentence, then a space, then `Activity-Triggered Switching resumes automatically.` Reason priority, independent of array order:
   - `.sleeping` → `The Mac is sleeping.`
   - `.inactiveSession` → `The session is locked.`
   - `.secureInput` → `Secure Input is active.`
   - `.protectedDataUnavailable` → `Protected data is unavailable.`
   - If none of those are present, the detail is only `Activity-Triggered Switching resumes automatically.`
3. **Paused.** No notice. Return nil, so the header carries the paused state instead. Give `MenuBarPanelContent` a `let pausedMarker: String?`, set to `"(paused)"` when `outcome.switchingStatus == .paused` and to nil otherwise. `MenuBarPanelHeader` takes `pausedMarker: String?` and renders it beside the `Keyameleon` title in secondary style, hidden from accessibility because the panel value already speaks the Switching Status. Resume stays in the footer.
4. **Ready, selection failure.** If `outcome.warnings` contains `.selectionFailed`, title `Couldn't select the Keyboard Assignment`. Detail is `Retry the Keyboard Assignment for <name>.` when `physicalKeyboardName` is non-nil, otherwise `Retry the Keyboard Assignment.` Action is Retry Now (`id: .retryNow`, title `Retry Now`, `closesPanel: false`) only when `outcome.hasAction(.retryNow)`. This case outranks mismatch and unassigned keyboards.
5. **Ready, mismatch.** If `outcome.mismatch` is non-nil, title `Input Source differs`. Detail is `The current Input Source is <currentName>. <Active Physical Keyboard name>'s Keyboard Assignment is <assignedName>.` when `outcome.activePhysicalKeyboard?.name` is non-nil. Otherwise omit the keyboard name: `The current Input Source is <currentName>. The Keyboard Assignment is <assignedName>.` Action nil.
6. **Ready, unassigned.** Physical Keyboards whose `assignmentState` is `.unassigned`, in the array order given, with no extra sort:
   - 1 → `<name> has no Keyboard Assignment.`
   - 2 → `<first> and <second> have no Keyboard Assignment.`
   - 3 or more → `<count> Physical Keyboards have no Keyboard Assignment.`
   - Title `Keyboard Assignment needed`. Action nil.
7. **Ready, Guided setup incomplete.** Title `Guided setup is not finished`. Detail `Open Settings to assign an Input Source.` Action nil.
8. Otherwise return nil.

Do not build a notice for an Unavailable Keyboard Assignment. The assignment row already shows that.

Add `case retryNow` to `MenuBarPanelActionID` in `MenuBarPanelContent.swift`. Give `MenuBarPanelContent` a `let notice: MenuBarPanelNotice?`. Add `isSetupComplete: Bool = true` as the last initializer parameter and set `notice` from `MenuBarPanelNotice.make`. Leave `makeActions` unchanged.

In `MenuBarActionList.swift`, add `case .retryNow: "arrow.clockwise"` to the private `iconName` switch so it still compiles. `MenuBarActionShortcut` already has a `default` and needs no new shortcut.

**Verify**: `rg -n "struct MenuBarPanelNotice" Sources/Features/Menu/MenuBarPanelNotice.swift` prints a match. `rg -n "case retryNow" Sources/Features/Menu/MenuBarPanelContent.swift Sources/Features/Menu/MenuBarActionList.swift` prints both files.

### Step 2: Lock the notice with Swift Testing

In `Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift`, keep every existing footer assertion. Add tests in that file so they can use the private `makeMenuBarPanelContent` and `makePanelKeyboard` helpers. Pass `isSetupComplete:` only when the test needs `false`.

Build outcomes that need `mismatch` or `warnings` with the memberwise initializer. The private `fixture` helper always passes `mismatch: nil` and `warnings: []`; do not change that helper's defaults. A mismatch outcome looks like this:

```swift
ActivityTriggeredSwitchingOutcome(
    switchingStatus: .ready,
    temporarilyUnavailableReasons: [],
    activePhysicalKeyboard: ActivityTriggeredSwitchingActivePhysicalKeyboard(
        name: "Travel",
        connectionState: .connected,
        assignment: .assigned(name: "U.S.")
    ),
    currentKeyboardAssignment: .assigned(name: "U.S."),
    currentInputSourceName: "Italian",
    mismatch: ActivityTriggeredSwitchingMismatch(
        currentName: "Italian",
        assignedName: "U.S."
    ),
    warnings: [],
    availableActions: [.pause]
)
```

A selection-failure warning is `ActivityTriggeredSwitchingWarning(physicalKeyboardName: "Travel", category: .selectionFailed, recoveryAction: .retryNow)`. Put it in `warnings` and, for the button case, include `.retryNow` in `availableActions`.

Cover these cases:

- Ready, one assigned Physical Keyboard, nil mismatch, empty warnings, setup complete → `notice == nil`. Footer ids stay `[.pause, .settings, .quit]`.
- Permission Required fixture → notice title `Permission Required`, action id `.requestPermission`, action title `Request Permission`, `closesPanel == false`. Footer ids stay `[.pause, .settings, .quit]`. `actionTitles` does not contain `Request Permission`.
- Temporarily Unavailable fixture (reasons `[.sleeping]`) → detail is `The Mac is sleeping. Activity-Triggered Switching resumes automatically.` Action nil. Footer still contains `.pause`.
- Temporarily Unavailable with reasons `[.secureInput, .sleeping]` → detail starts with `The Mac is sleeping.`
- Paused fixture → `notice == nil`, `pausedMarker == "(paused)"`, and the footer still offers Resume.
- Ready, Temporarily Unavailable, and Permission Required fixtures → `pausedMarker == nil`.
- Ready with `ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S.")` and `activePhysicalKeyboard` name `Travel` → detail is `The current Input Source is Italian. Travel's Keyboard Assignment is U.S.` Action nil.
- Ready with a warning `ActivityTriggeredSwitchingWarning(physicalKeyboardName: "Travel", category: .selectionFailed, recoveryAction: .retryNow)` and `availableActions` containing `.retryNow` → action title `Retry Now`.
- The same warning with `availableActions` equal to `[.pause]` → notice exists, action nil.
- Ready, one `.unassigned` Physical Keyboard named `Travel` → detail `Travel has no Keyboard Assignment.`
- Ready, three unassigned Physical Keyboards → detail `3 Physical Keyboards have no Keyboard Assignment.`
- Ready, one assigned keyboard whose id is absent from `assignedInputSourceNames` (the list marks it unavailable) and no other condition → `notice == nil`.
- Permission Required plus an unassigned Physical Keyboard → title stays `Permission Required`.
- Ready, `isSetupComplete: false`, no keyboards → title `Guided setup is not finished`.

**Verify**: this step does not compile until Step 3 generates the project. Confirm the new `@Test` names exist with `rg -n "Keyboard Assignment needed|Input Source differs|Retry Now" Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift`.

### Step 3: Show the notice and speak it

Create `Sources/Features/Menu/MenuBarPanelNoticeView.swift`. `@MainActor struct MenuBarPanelNoticeView: View` takes the notice, a `FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding`, and `perform: (MenuBarPanelContent.Action) -> Void`.

Layout, top to bottom: title, detail, then the button only when `action` is non-nil. Title uses `.font(.body.weight(.medium))`. Detail uses `.font(.callout)` and `.foregroundStyle(.secondary)` and wraps. The button is `Button(action.title) { perform(action) }` with `.buttonStyle(.bordered)`, `.focusable()`, focused as `.action(id: action.id)`, and `.accessibilityIdentifier("menu-bar-notice-\(action.id.rawValue)")`. The container uses `.accessibilityElement(children: .contain)`, label = title, value = detail, identifier `menu-bar-notice`. Horizontal padding 12, matching `MenuBarAssignmentSection` in `MenuBarPanelView`. Do not set a fixed height. Do not use `CGSize`.

Add `#if DEBUG` / `#Preview("Menu-bar notice")` in that file showing the Permission Required notice at `MenuBarPanelContent.panelWidth`. Copy the `@Previewable @FocusState` shape from the "Menu-bar actions" preview in `MenuBarActionList.swift`.

In `MenuBarPanelAccessibility`:

- Add `let notice: Speech?`. When `content.notice` is non-nil, its label is the notice title and its value is the notice detail. Otherwise nil.
- Store the notice action title, if any, separately from `actions`. `actions` stays the footer only. `menuBarPanelAccessibilityLiveUpdatesWithSwitchingStatus` must keep `permission.accessibility.actions.map(\.label) == ["Pause", "Settings", "Quit Keyameleon"]`.
- `voiceOverOrderLabels` is panel label, About label, notice title if present, notice action title if present, assignment item labels, footer action labels.
- `keyboardOperationTitles` is About, notice action title if present, assignment names, footer action titles.
- `keyboardFocusOrder` inserts `.action(id:)` for the notice action immediately after `.about` when the notice has an action. No extra focus target when the action is nil.

In `KeyameleonMenuBarPanelView.body`, when `content.notice` is non-nil, put `MenuBarPanelNoticeView` after the header `Divider` and before `MenuBarAssignmentSection`. Pass the same `perform` and `$focusedTarget`. In `makeContent()`, pass `isSetupComplete: setupModel.isSetupComplete`. In `perform`, add `case .retryNow: switching.retryNow()`.

Update `menuBarPanelKeyboardFocusOrderVisitsAssignmentsThenActions` in place. Do not reorder Desk and Travel. The Permission Required focus order gains `.action(id: .requestPermission)` immediately after `.about`. `keyboardOperationTitles` for that same panel becomes `About Keyameleon`, `Request Permission`, `Desk`, `Travel`, `Pause`, `Settings`, `Quit Keyameleon`. The Ready empty-panel focus expectation in that test stays unchanged. On that Permission Required panel, `voiceOverOrderLabels` is `Keyameleon`, `About Keyameleon`, `Permission Required`, `Request Permission`, then the same assignment names already in `keyboardOperationTitles`, then `Pause`, `Settings`, `Quit Keyameleon`.

Run `./Scripts/run.sh generate`.

**Verify**: `python3 -m unittest Tests/Scripts/test_preview_coverage.py` prints `OK`. `rg -n "case retryNow" Sources/Features/Menu/MenuBarPanelView.swift` prints a match. `./Scripts/run.sh audit` exits 0.

### Step 4: Run the product tests

**Verify**: `./Scripts/run.sh test` exits 0.

## Test plan

- New tests live in `Tests/SwiftTesting/Features/Menu/MenuBarPanelTests.swift` and `MenuBarPanelAccessibilityTests.swift`, as listed in Step 2 and Step 3.
- Pattern: the existing `@Test` functions and `makeMenuBarPanelContent` in those files.
- No XCTest and no UI test.
- `./Scripts/run.sh test` exits 0, including the new tests and the unchanged footer tests.

## Done criteria

- [ ] `./Scripts/run.sh test` exits 0
- [ ] `python3 -m unittest Tests/Scripts/test_preview_coverage.py` prints `OK`
- [ ] A Ready panel with no mismatch, no selection failure, no unassigned Physical Keyboard, and completed setup has `notice == nil`
- [ ] Permission Required shows a Request Permission notice action and the footer ids remain `[.pause, .settings, .quit]`
- [ ] A Paused panel shows `pausedMarker == "(paused)"`, no notice, and Resume in the footer
- [ ] `rg -n "Check Again|Open System Settings" Sources/Features/Menu/MenuBarPanelNotice.swift` prints no matches
- [ ] `rg -n "first-key|First-Key|guarantee" Sources/Features/Menu/MenuBarPanelNotice.swift` prints no matches
- [ ] `git status --short` shows only files in the in-scope list, plus `plans/README.md`
- [ ] `plans/README.md` status row for 001 is `DONE`

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" do not match the files at those symbols.
- `makeActions` is no longer limited to pause or resume, Settings, and Quit.
- Showing the notice seems to require a second button, a footer recovery row, or an editable Keyboard Assignment.
- `./Scripts/run.sh generate` fails, or `xcodegen` is missing.
- `./Scripts/run.sh test` fails twice after a fix that stays inside the in-scope files.
- The notice copy would need a phrase `CONTEXT.md` tells you to avoid.
- A fix requires editing `ActivityTriggeredSwitching.swift` or the icon mark.

## Maintenance notes

- The notice priority is the product contract. A new Switching Status or warning category has to be placed in that list on purpose, in `MenuBarPanelNotice.make` and in `MenuBarPanelTests`.
- Paused is the one status with no notice block. It rides on the header as `MenuBarPanelContent.pausedMarker`, because the panel is already open and the paused state needs one word, not a paragraph. A status that needs an action still belongs in the notice ladder.
- Reviewers should check that the footer tests still forbid recovery actions in the footer, and that Retry Now calls `switching.retryNow()` rather than a new selection path.
- Request Permission keeps the panel open (`closesPanel: false`). If a later change finds the system permission prompt hidden behind the panel, flip only that action's `closesPanel` to `true` and update the Permission Required test.
- Unavailable Keyboard Assignment stays on the row. Do not also add a panel notice for it unless the row copy is removed.
- Plan 003 owns the Guided setup sentence about the key that changes the Active Physical Keyboard. Do not copy that sentence into this notice.
