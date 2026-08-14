# Project Environment

Inspected 2026-08-14. Native Swift 6 macOS 26 menu-bar app (AppKit + SwiftUI + SwiftData). Not React Native. Not iOS/Android. Argent device tools do not apply.

- Run: `./Scripts/run.sh open`
- Test: `./Scripts/run.sh test`
- Generate after `project.yml` edits: `./Scripts/run.sh generate`
- Debug bundle id: `dev.fedemas.keyameleon.development`
- Release bundle id: `dev.fedemas.keyameleon`
- Derived data: `./build`
- Single-instance lock (ADR 0002). LSUIElement agent, no Dock.
- Domain names: `CONTEXT.md`
