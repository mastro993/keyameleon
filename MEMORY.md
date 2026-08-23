# Project Environment

Inspected 2026-08-17. Native macOS 26 LSUIElement menu-bar app (Swift 6 + AppKit + SwiftUI + SwiftData). XcodeGen `Keyameleon.xcodeproj`. Sparkle 2.9.5. Not React Native / Expo / Flutter / iOS / Android. Argent simulator/emulator tools do not apply.

- Run: `./Scripts/run.sh open` (Development-signed Debug; Input Monitoring persists)
- Test: `./Scripts/run.sh test` (audit first; UI tests then Swift Testing + XCTest)
- Audit: `./Scripts/run.sh audit`
- Generate after `project.yml` edits: `./Scripts/run.sh generate`
- Official Release (not local): `./Scripts/official-release.sh` with `RELEASE_TAG=vX.Y.Z`. `SKIP_NOTARIZE=1` is not Official.
- Debug bundle id: `dev.fedemas.keyameleon.development`
- Release bundle id: `dev.fedemas.keyameleon`
- Derived data: `./build`
- Scheme: `Keyameleon` — app + `KeyameleonSwiftTesting` + `KeyameleonXCTest` + `KeyameleonUITests`
- Single-instance lock (ADR 0002). LSUIElement agent, no Dock. Quit the running instance before relaunch.
- Domain names: `CONTEXT.md`
- Sparkle feed: `https://mastro993.github.io/Keyameleon/appcast.xml`
- Official artifacts: DMG on GitHub Release; appcast on GitHub Pages; evidence as workflow artifact (ADR 0006)
- CI: GitHub Actions `Required CI gate`; macos-26, 8 min. Release waits via `Scripts/wait-for-ci.sh`.
- Issues via `gh` CLI.
