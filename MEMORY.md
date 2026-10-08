# Project Environment

Quick reference for agents. Native macOS 26 `LSUIElement` menu bar app (Swift 6, AppKit, SwiftUI, SwiftData), generated with XcodeGen from `project.yml`. Sparkle 2.10.0 is the only package. Not React Native, Expo, Flutter, iOS, or Android, so simulator and emulator tools do not apply.

- Run: `./Scripts/run.sh open` (Development-signed Debug; Input Monitoring persists)
- Test: `./Scripts/run.sh test` (audit, SwiftLint, script tests, Swift Testing, XCTest; no UI-test target)
- Audit only: `./Scripts/run.sh audit`
- Regenerate after `project.yml` edits: `./Scripts/run.sh generate`
- Bundle ID: `dev.fedemas.keyameleon`, shared by Debug and Release builds
- Derived data: `./build`
- Scheme: `Keyameleon` (app, `KeyameleonSwiftTesting`, `KeyameleonXCTest`)
- One instance per Mac (ADR 0002). Quit any running Keyameleon, including an installed release, before launching or testing.
- Domain vocabulary: `CONTEXT.md`. Current design decisions: `docs/choices.md`.
- Sparkle feed: `https://mastro993.github.io/keyameleon/appcast.xml`
- Official Releases: Release `workflow_dispatch` on `main` only. DMG on GitHub Releases; appcast and evidence on GitHub Pages; cask in `mastro993/homebrew-tap` (ADR 0004, ADR 0006). Local `./Scripts/official-release.sh` output is never an Official Release.
- CI: `Required CI gate`; `macos-26`, 8-minute limit. The Release workflow waits for it with `Scripts/wait-for-ci.sh`.
- Issues: `gh` CLI (`docs/agents/issue-tracker.md`).
