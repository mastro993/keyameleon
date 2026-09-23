# Plan 002: Lock Input Source selection to Activation Activity

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c3a172f..HEAD -- Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching.swift Tests/SwiftTesting/Features/ActivityTriggeredSwitching/LifecycleTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `c3a172f`, 2026-09-22

## Why this matters

Keyameleon selects an Input Source only after Activation Activity: a key press or repeat on one Physical Keyboard. Connect, disconnect, wake, and unlock do not select. The key that moves to another Physical Keyboard can therefore still use the previous Input Source. `CONTEXT.md` states that limit, and the V1 spec leaves a First-Key Guarantee, Virtual HID, and keyboard seizure out of scope.

The open product question is narrower than that. When the Active Physical Keyboard disconnects and exactly one other connected Physical Keyboard already has a Keyboard Assignment, selecting that saved assignment would not seize a keyboard and would not guess an identity. It would still change two shipped rules: a disconnected Active Physical Keyboard stays active, and an external or lifecycle change waits for later Activation Activity.

This plan does **not** adopt that rule. It locks today's behavior with tests so a later change has to break those tests on purpose. Plan 003's setup sentence describes this same rule. Do not implement early selection here.

## Current state

`Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching.swift` handles lifecycle by updating Temporarily Unavailable and calling `checkAgain()`. `checkAgain()` refreshes permission, the observed Input Source, and warnings. It does not call `applyWantedKeyboardAssignment`.

```swift
func handleLifecycleEvent(_ event: KeyameleonLifecycleEvent) {
    switch event {
    case .willSleep:
        updateUnavailableReason(.sleeping, isActive: true)
    case .didWake:
        updateUnavailableReason(.sleeping, isActive: false)
    case .sessionDidResignActive:
        updateUnavailableReason(.inactiveSession, isActive: true)
    case .sessionDidBecomeActive:
        updateUnavailableReason(.inactiveSession, isActive: false)
    // protected-data cases update .protectedDataUnavailable
    }
    checkAgain()
}
```

Connect and disconnect only log. They do not select:

```swift
private func handleDiscoveryRecordChange(
    _ change: PhysicalKeyboardDiscoveryRecordChange
) {
    switch change {
    case let .connected(physicalKeyboardID, name):
        // logs "Physical Keyboard connected"
    case let .disconnected(physicalKeyboardID, name):
        // logs "Physical Keyboard disconnected"
    }
}
```

`handleActivationActivity` is the path that calls `applyWantedKeyboardAssignment` for an assigned Physical Keyboard. A release-only event is not Activation Activity.

Saving a Keyboard Assignment updates the record and does not select. `reconcileWantedAssignmentFromRecords()` rewrites the in-memory wanted assignment when the saved identifier changes. It does not call `applyWantedKeyboardAssignment`. The picker already says "Applies after next Activation Activity".

`Tests/SwiftTesting/Features/ActivityTriggeredSwitching/LifecycleTests.swift` already covers one keyboard in `disconnectedActivePhysicalKeyboardStaysActiveWithNoInputSourceRequest`: after disconnect, that keyboard stays active and `selector.selectCount` stays 0. It does not cover a second, still-connected, assigned Physical Keyboard. It does not cover wake or a new connection.

The private helper at the bottom of that file is `makeLifecycleModel(recordStore:discoverer:selector:setupStore:)`. It uses `SetupModelTestListenPermissionProvider(state: .granted)` and an input-source catalog containing `com.example.us` ("U.S.") and `com.example.italian` ("Italian"). `makeSetupModelHardwareFacts(serviceID:identity:serialNumber:)` lives in `Tests/SwiftTesting/Features/Onboarding/SetupModelTests.swift` and is internal to the test module. `startAndCheck(_:)` is in `Tests/SwiftTesting/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitchingTestSupport.swift`. `SetupModelTestInputSourceSelector` exposes `selectCount`. `ActivityTriggeredSwitching.markActiveForTesting(_:)` sets the Active Physical Keyboard without selecting. `handleLifecycleEvent(_:)` is internal to the module and visible to `@testable import Keyameleon`.

Two Physical Keyboards need different `identity` and `serialNumber` values. The same default identity would collapse them into one record.

Glossary constraint, from `CONTEXT.md`:

> Activity-Triggered Switching requests and verifies a Keyboard Assignment after Keyameleon observes Activation Activity. It does not delay or change the original Physical Keyboard Event. That event and later events that macOS processes before verification can use the previous Input Source.

Avoid "first-key guarantee", "next-key guarantee", and "best-effort switching" in test names and comments.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Product tests | `./Scripts/run.sh test` | exit 0 |
| Safety audit, if you need a shorter check after a test-only edit | `./Scripts/run.sh audit` | exit 0 |

`./Scripts/run.sh test` needs Xcode and writes under `./build`. Do not add a new Swift file in this plan, so do not run `generate`.

## Scope

**In scope**:

- `Tests/SwiftTesting/Features/ActivityTriggeredSwitching/LifecycleTests.swift`
- `plans/README.md` status row for 002

**Out of scope** (do not touch, even though they look related):

- `Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching.swift` and every other production file. No new selection trigger.
- `docs/choices.md`, `docs/adr/`, `CONTEXT.md`, and `OnboardingView.swift`. Plan 003 owns the setup sentence. This plan's decision lives in this file, not in a new ADR.
- `ProtectedLifecycleTests.swift`. Sleep and lock observation counts are already tested there. Do not duplicate them.
- Virtual HID, `seizeDevice`, event taps, synthetic events, and any API the safety audit forbids (`CGEvent`, `IOHIDPostEvent`, `HIDVirtualDevice`).
- Do not install packages or change `project.yml`.

## Git workflow

- Branch from current `HEAD`: `advisor/002-lock-activation-activity-selection`
- One commit at the end, after `./Scripts/run.sh test` exits 0: `test(switching): lock Input Source selection to Activation Activity`
- Do not push or open a pull request.
- Do not rebase onto `main` as part of this plan.

## Steps

### Step 1: Add three characterization tests

Add the tests below to `LifecycleTests.swift`, above the private `makeLifecycleModel` helper. Use that helper. Do not copy a second model factory. Do not change production code.

Each test uses two distinct identities when it connects two keyboards: `macos.keyboard.alpha` / `serial-alpha` and `macos.keyboard.beta` / `serial-beta`. Assign `com.example.us` and `com.example.italian` from the helper's catalog. Construct the selector as `SetupModelTestInputSourceSelector(current: "com.example.us")` so a selection of Italian would increment `selectCount`.

Resolve a connected keyboard's id the way the sort test in this file does: `model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }`. The record id contains the identity string. Do not use the service id as the record id.

1. `@Test("Disconnecting the Active Physical Keyboard does not select the remaining Keyboard Assignment")`

   Connect both keyboards. Assign each. `markActiveForTesting` on the alpha id. Record `selector.selectCount`. Disconnect service `801` (alpha). Expect `selectCount` unchanged, `activePhysicalKeyboardID` still alpha, and the beta keyboard still `.connected` and not `isActive`.

2. `@Test("Connecting an assigned Physical Keyboard does not select its Keyboard Assignment")`

   Connect and assign alpha. `markActiveForTesting` on alpha. Record `selectCount`. Connect and assign beta. Expect `selectCount` unchanged, the active id still alpha, and beta not `isActive`.

3. `@Test("Wake and unlock do not select the Active Keyboard Assignment")`

   Connect and assign one keyboard to `com.example.italian`. `markActiveForTesting`. Expect `selectCount == 0`. Call `handleLifecycleEvent(.willSleep)` then `.didWake`. Expect `selectCount == 0` and the same active id. Call `.sessionDidResignActive` then `.sessionDidBecomeActive`. Expect `selectCount == 0` and the same active id.

Use service ids `801` and `802` so they do not collide with existing literals in this file in a way that matters; the discoverer is per test, so uniqueness inside the test is what matters. Do not assert log text. Do not assert observation start counts.

A press on an assigned keyboard must still select. Do not weaken `assignedActivationActivityRequestsExactKeyboardAssignmentAndVerifiesReadback` in `SwitchingTests.swift`. This plan does not edit that file. If you need to prove the positive path, the existing test already does.

**Verify**: `rg -n "does not select the remaining Keyboard Assignment|does not select its Keyboard Assignment|Wake and unlock do not select" Tests/SwiftTesting/Features/ActivityTriggeredSwitching/LifecycleTests.swift` prints three matches. `git diff --stat -- Sources` prints nothing.

### Step 2: Run the product tests

**Verify**: `./Scripts/run.sh test` exits 0.

## Decision this spike records

Adopted for now: Keyameleon selects a Keyboard Assignment only from Activation Activity (`handleActivationActivity`) and from explicit Retry Now. Connect, disconnect, wake, unlock, and saving an assignment do not select.

Not adopted, and not to be coded from this plan: when the Active Physical Keyboard disconnects and exactly one other connected Physical Keyboard has a Keyboard Assignment, select that assignment. Also not adopted: selecting on wake, on unlock, or whenever a second keyboard connects. Those alternatives would contradict the test `disconnectedActivePhysicalKeyboardStaysActiveWithNoInputSourceRequest`, story 70 of the V1 spec (a disconnected Active Physical Keyboard stays active), and the glossary sentence quoted above.

If a later plan adopts the sole-remaining-keyboard rule, it has to do all of the following in one change:

- Change only the disconnect case where the disconnected keyboard was the Active Physical Keyboard, exactly one other connected Physical Keyboard has a Keyboard Assignment, Switching Status is Ready, and that assignment is available.
- Leave two connected assigned keyboards alone until Activation Activity.
- Leave an unassigned remaining keyboard alone.
- Leave wake, unlock, and assignment-save behavior alone.
- Update the three tests from this plan and `disconnectedActivePhysicalKeyboardStaysActiveWithNoInputSourceRequest` in the same change.
- Update plan 003's setup sentence in the same change. The sentence would be false if disconnect started selecting.
- Stay monitor-only. No Virtual HID, no seizure, no delayed or synthetic Physical Keyboard Event.

Until that later plan exists, plan 003 tells the user about the current limit.

## Test plan

- Three new `@Test` functions in `LifecycleTests.swift`, described in Step 1.
- Pattern: `disconnectedActivePhysicalKeyboardStaysActiveWithNoInputSourceRequest` in the same file, and `makeLifecycleModel`.
- No production assertions beyond `selectCount`, the active id, and connection / `isActive` on the keyboards under test.
- `./Scripts/run.sh test` exits 0.

## Done criteria

- [ ] `./Scripts/run.sh test` exits 0
- [ ] The three new test names exist in `LifecycleTests.swift`
- [ ] `git diff --stat -- Sources docs CONTEXT.md` prints nothing
- [ ] `git status --short` shows only `Tests/SwiftTesting/Features/ActivityTriggeredSwitching/LifecycleTests.swift` and `plans/README.md`
- [ ] `plans/README.md` status row for 002 is `DONE`

## STOP conditions

Stop and report back (do not improvise) if:

- `handleLifecycleEvent` or `handleDiscoveryRecordChange` already calls `applyWantedKeyboardAssignment` or otherwise selects an Input Source. The premise of this plan is false.
- After `setKeyboardAssignment` and `markActiveForTesting`, `selectCount` is already non-zero. Saving an assignment is not supposed to select. Report that instead of loosening the wake test.
- `makeLifecycleModel` no longer takes a `selector:` or no longer offers `com.example.italian`.
- A new test cannot express two Physical Keyboards without changing production identity rules.
- You believe the sole-remaining-keyboard rule should ship in this change. It must not. Report that, and leave production code untouched.
- `./Scripts/run.sh test` fails twice after a fix that stays inside `LifecycleTests.swift`.
- Making the tests pass seems to require editing `ActivityTriggeredSwitching.swift`.

## Maintenance notes

- These tests are the contract plan 003's sentence relies on. If selection starts happening on disconnect, wake, or connect, update the sentence in the same pull request.
- A reviewer should confirm the diff is test-only and that `selectCount` is compared against a recorded value, not against a hardcoded `0` that hides a select performed while arranging the test. Recording `selectCount` before the disconnect or connect is the arrangement used above. The wake test can expect `0` because `markActiveForTesting` and `setKeyboardAssignment` do not select.
- Do not treat this plan's "Not adopted" section as permission to start the implementation inside the same branch.
