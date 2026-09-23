# Plan 003: Guided setup explains the Activation Activity Input Source limit

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c3a172f..HEAD -- Sources/Features/Onboarding/OnboardingView.swift`
> If that file changed since this plan was written, compare the "Current state"
> excerpt against the live code before proceeding; on a mismatch, treat it as
> a STOP condition.
>
> Also confirm plan 002 is `DONE` in `plans/README.md` and that its decision
> still says selection stays on Activation Activity. If plan 002 is not `DONE`,
> or its decision was edited to adopt selection on disconnect, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/002-lock-activation-activity-selection.md
- **Category**: direction
- **Planned at**: commit `c3a172f`, 2026-09-22

## Why this matters

V1 asked Guided setup to explain which early typing can use the previous Input Source. The 14 August 2026 choices removed the "First-Key Guarantee" wording from the glossary, the README, and the UI, and no replacement sentence was added. The assignment step currently tells the person to connect keyboards and assign an Input Source. It does not say that the key press which makes a different Physical Keyboard active can still be interpreted by the previous Input Source.

Plan 002 keeps selection on Activation Activity. This sentence matches that rule. It uses glossary terms and does not revive the banned phrase.

## Current state

`Sources/Features/Onboarding/OnboardingView.swift` is `@MainActor`. The assignment step subtitle is:

```swift
private var stepSubtitle: String {
    if model.guidedSetupStep == .assignments {
        "Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings."
    } else {
        "Keyameleon needs Input Monitoring to observe Activation Activity from each Physical Keyboard."
    }
}
```

`header` renders `Text(stepSubtitle)` with `.font(.body)`, `.foregroundStyle(.secondary)`, `.multilineTextAlignment(.center)`, and `.frame(maxWidth: 420)`. A longer string wraps in that text. Do not add a second text style.

`Sources/Features/Shared/KeyboardAssignmentPickerView.swift` line 25 already says `Applies after next Activation Activity`. That sentence is about a saved edit, not about moving between Physical Keyboards. Leave it.

`CONTEXT.md` defines Activity-Triggered Switching as selecting after Activation Activity, and says the event that causes the change, and later events before verification, can use the previous Input Source. Avoid "first-key guarantee", "next-key guarantee", and "best-effort switching".

There is no string catalog. Copy is a literal at the view that shows it. There is no UI-test target. A static string on the view is the test seam.

`KeyameleonOnboardingView` is `@MainActor`, so a test that reads a static member on it must be `@MainActor`.

New test files under `Tests/SwiftTesting` are not compiled until `./Scripts/run.sh generate` rewrites `Keyameleon.xcodeproj/project.pbxproj`. `Tests/Scripts/test_preview_coverage.py` does not apply to this change unless you add a new non-private `View` type. Do not add one.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Regenerate the Xcode project after adding the test file | `./Scripts/run.sh generate` | exit 0 |
| Product tests | `./Scripts/run.sh test` | exit 0 |

If `xcodegen` is not on `PATH`, STOP. Do not install it.

## Scope

**In scope**:

- `Sources/Features/Onboarding/OnboardingView.swift`
- `Tests/SwiftTesting/Features/Onboarding/OnboardingCopyTests.swift` (create)
- `Keyameleon.xcodeproj/` changes produced by `./Scripts/run.sh generate`
- `plans/README.md` status row for 003

**Out of scope**:

- `KeyboardAssignmentPickerView.swift`. Do not repeat the new sentence there.
- `MenuBarPanelNotice.swift` and the rest of the menu-bar panel. Plan 001 owns the panel notice. Do not paste this sentence into it.
- `ActivityTriggeredSwitching.swift` and `LifecycleTests.swift`. If those tests no longer match the sentence, STOP rather than changing switching.
- README, `CONTEXT.md`, `docs/choices.md`, and ADRs.
- Permission-step copy. It stays the Input Monitoring sentence.

## Git workflow

- Branch from current `HEAD`: `advisor/003-guided-setup-switching-limit`
- One commit at the end, after `./Scripts/run.sh test` exits 0: `feat(onboarding): explain the Activation Activity Input Source limit`
- Do not push or open a pull request.
- Do not rebase onto `main` as part of this plan.

## Steps

### Step 1: Replace the assignment subtitle with a static string

On `KeyameleonOnboardingView`, add this static member and use it for the assignment branch of `stepSubtitle`. Leave the permission branch as the existing literal.

```swift
static let assignmentStepSubtitle = """
Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings.

When you start typing on a different Physical Keyboard, that first key press can still use the previous Input Source. Keyameleon then selects that keyboard's Keyboard Assignment.
"""
```

`stepSubtitle` becomes:

```swift
if model.guidedSetupStep == .assignments {
    Self.assignmentStepSubtitle
} else {
    "Keyameleon needs Input Monitoring to observe Activation Activity from each Physical Keyboard."
}
```

Do not change `header`, fonts, or layout. The existing `Text(stepSubtitle)` shows both paragraphs.

**Verify**: `rg -n "assignmentStepSubtitle" Sources/Features/Onboarding/OnboardingView.swift` prints the static let and its use. `rg -n "first-key|First-Key|guarantee|best-effort" Sources/Features/Onboarding/OnboardingView.swift` prints no matches.

### Step 2: Assert the exact sentence

Create `Tests/SwiftTesting/Features/Onboarding/OnboardingCopyTests.swift` with this test and nothing else:

```swift
import Testing
@testable import Keyameleon

@Test("Guided setup assignment step explains the Activation Activity limit")
@MainActor
func guidedSetupAssignmentStepExplainsActivationActivityLimit() {
    let copy = KeyameleonOnboardingView.assignmentStepSubtitle
    #expect(copy == """
    Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings.

    When you start typing on a different Physical Keyboard, that first key press can still use the previous Input Source. Keyameleon then selects that keyboard's Keyboard Assignment.
    """)
    #expect(copy.contains("First-Key") == false)
    #expect(copy.contains("first-key") == false)
    #expect(copy.contains("guarantee") == false)
    #expect(copy.contains("best-effort") == false)
}
```

Run `./Scripts/run.sh generate`.

**Verify**: `rg -n "OnboardingCopyTests.swift" Keyameleon.xcodeproj/project.pbxproj` prints at least one match. `./Scripts/run.sh test` exits 0.

## Test plan

- One Swift Testing function, `guidedSetupAssignmentStepExplainsActivationActivityLimit`, in `Tests/SwiftTesting/Features/Onboarding/OnboardingCopyTests.swift`.
- It asserts the full assignment subtitle, including the existing first paragraph, so a later edit cannot drop either sentence silently.
- It rejects the banned phrases by literal `contains`. This is the app's own copy, not user input, so `localizedStandardContains` is not required.
- No view inspection, snapshot, or UI test.
- `./Scripts/run.sh test` exits 0.

## Done criteria

- [ ] `./Scripts/run.sh test` exits 0
- [ ] The assignment step subtitle is `KeyameleonOnboardingView.assignmentStepSubtitle` and equals the string in Step 1
- [ ] The permission subtitle is still `Keyameleon needs Input Monitoring to observe Activation Activity from each Physical Keyboard.`
- [ ] `rg -n "first-key|First-Key|guarantee|best-effort" Sources/Features/Onboarding/OnboardingView.swift` prints no matches
- [ ] `KeyboardAssignmentPickerView.swift` still contains `Applies after next Activation Activity` and does not contain `that first key press`
- [ ] `git status --short` shows only in-scope files
- [ ] `plans/README.md` status row for 003 is `DONE`

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 002 is not `DONE`, or its "Decision this spike records" section no longer says selection stays on Activation Activity.
- `LifecycleTests.swift` contains a test whose name or assertions expect a disconnect, connect, wake, or unlock to increment an Input Source selection count. The sentence in Step 1 would be wrong.
- `stepSubtitle` is gone or is no longer what `header` displays.
- You want a different sentence, a second visual block, or the same copy in Settings or the menu-bar panel. Use the sentence in Step 1.
- `./Scripts/run.sh generate` fails, or `xcodegen` is missing.
- `./Scripts/run.sh test` fails twice after a fix that stays inside the in-scope files.
- The view's main-actor isolation rejects a `static let` read from the test. Do not drop `@MainActor` on the test and do not mark the copy `nonisolated` unless the compiler requires it; if it does, report the diagnostic before changing isolation.

## Maintenance notes

- If a later change selects a Keyboard Assignment on disconnect, rewrite `assignmentStepSubtitle` in that same change. The second paragraph is true only while selection waits for Activation Activity.
- Reviewers should check the second paragraph uses Physical Keyboard, Input Source, Keyboard Assignment, and Activation Activity, and that the first paragraph is unchanged.
- The picker sentence "Applies after next Activation Activity" remains the copy for a saved edit. Do not merge the two sentences.
