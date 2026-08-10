# Breadcrumbs

## 2026-08-10 — Issue #9 Manual Physical Keyboard Designation

- Issue #9: leave/return/name confirmation for eligible ambiguous external identity groups.
- Domain: evidence rules + CryptoKit authenticator + phase enum.
- App: Keychain integrity key, designation store, SetupModel session + elevation on publish/event.
- UI: start button, status banner, name confirmation sheet.
- Tests: `KeyameleonManualDesignationTests.swift` (eligibility, auth, flow, shared reject, empty name, no migrate, tamper).
- Suite green.
- Merged main: keep #6 converge + #7 menu first / pause.

## 2026-08-10 — Issue #7

- Menu first daily surface: Switching Status, Active PK, Keyboard Assignment, Current Input Source, action items, Pause/Resume.
- Pause persists; Active PK does not. Icon marks: permission / warning / pause (+ temp unavailable).
- Tests: `KeyameleonMenuFirstTests` + XCTest menu cases.
- Merged main #6: keep wanted-generation converge + mismatch menu lines.
- Follow-on: #11 sleep/lock → Temporarily Unavailable; #10 unavailable recovery actions; #12 no notify while Paused.

## 2026-08-10 — Issue #6

- Issue #6: converge after rapid activity + external Input Source changes.
- Parent #1; blocked-by #5 closed.
- Shipped: wanted generation, stale-readback discard, external change observer (no fight), mismatch UI/menu, A-B-A + rapid-order tests.
- Out of scope: Pause (#7), Retry Now (#10 failure recovery).

## 2026-08-10 — Issue #5

- Issue #5: implement Activity-Triggered Switching.
- Parent #1; blocked-by #4 closed.
- Shipped: event domain, CoreHID listen-only observer, Input Source select+verify, SetupModel serial consumer, Active PK UI/menu, tests green.
- Out of scope here: pause (#7), rapid converge extras (#6), failure recovery (#10).
- Merged main: keep #8 lifecycle publish (connected+disconnected) + #15 Launch at Login / Sparkle.

## 2026-08-10 — Issue #15
- Implementing Launch at Login (`SMAppService.mainApp`) and Sparkle 2 user-approved updates behind General settings.
- Blocked-by #2 already closed; working on current branch `t3code/implement-issue-15`.

## 2026-08-10 — Issue #8 Manage Physical Keyboard lifecycle

- Tests: `Tests/SwiftTesting/KeyameleonLifecycleTests.swift` (9 cases).
- Domain: `PhysicalKeyboardConnectionState`, `PhysicalKeyboardListOrdering`, disconnected factory.
- Store: `allRecords`, `deleteRecord`, `transferRecord`.
- Model: merge connected catalog + saved disconnected; active ID; forget/replace; no Input Source request on disconnect.
- UI: connection/active labels; Replace picker + confirm; Forget confirm.
- Follow-on: #5 wires Activation Activity into event observer and real selection.
