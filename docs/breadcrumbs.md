# Breadcrumbs

## 2026-08-10 — Issue #13 Control Diagnostic Data and Diagnostic Sessions

- Domain: closed allowlist `DiagnosticCategory`/`DiagnosticEventCode`, session 10m, retention 7d/5MB, temporary tokens.
- Service: `KeyameleonDiagnosticDataService` + `InMemory`/`SwiftData` store; `ClockProviding`.
- Wire: SetupModel records operational state/errors; session-only detailed codes; forget deletes linked diagnostics.
- UI: General Settings → Diagnostics (start/stop session, clear all).
- Tests: `KeyameleonDiagnosticDataTests.swift`. Bundle export = #14.

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
