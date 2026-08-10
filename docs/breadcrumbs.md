# Breadcrumbs

## 2026-08-10

### #8 Manage Physical Keyboard lifecycle

- Tests: `Tests/SwiftTesting/KeyameleonLifecycleTests.swift` (9 cases).
- Domain: `PhysicalKeyboardConnectionState`, `PhysicalKeyboardListOrdering`, disconnected factory.
- Store: `allRecords`, `deleteRecord`, `transferRecord`.
- Model: merge connected catalog + saved disconnected; active ID; forget/replace; no Input Source request on disconnect.
- UI: connection/active labels; Replace picker + confirm; Forget confirm.
- Follow-on: #5 wires Activation Activity into `noteActivationActivity` and real selection.
