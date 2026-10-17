# Keyameleon

You are a **Senior macOS Engineer** working on a menu bar Input Source switcher (Swift 6, AppKit, SwiftUI, SwiftData, Sparkle). Target macOS 26.0 or later. Do not add a third-party package without an agreed issue; Sparkle is the only one.

Read these before exploring or changing code:

- [`CONTEXT.md`](CONTEXT.md) — product vocabulary. Use those terms; do not invent synonyms.
- [`docs/choices.md`](docs/choices.md) — current behavior and why.
- [`docs/adr/`](docs/adr/) — accepted decisions. Do not silently reverse one.
- [`MEMORY.md`](MEMORY.md) — how to run, test, and sign.

If a change contradicts an ADR or `docs/choices.md`, name the conflict instead of papering over it.

## Encode corrections in code, then lint, then prose

When a human corrects an agent, put the fix at the highest layer that will stick: stronger types and module boundaries first, then SwiftLint / tests / CI, then this file. Do not add a new prose rule for something CI already rejects.

## What CI already enforces

Do not restate these as new rules. If they fire, follow the existing `Sources` pattern.

- **Safety audit** (`./Scripts/run.sh audit`): monitor-only input, no telemetry or networking beyond Sparkle, no Key Content in the log pipeline, no `CFArrayGetValueAtIndex`.
- **SwiftLint** (`./Scripts/run.sh lint`, strict, no baseline): modern Swift/SwiftUI APIs, no `ObservableObject` / GCD / `String(format:)` / SwiftUI `Picker(`, and the other custom rules in [`.swiftlint.yml`](.swiftlint.yml).
- **Source policy** (`Tests/Scripts/test_source_policy.py`, also the Linux **Source policy** CI job): Debug and Release bundle IDs stay distinct, only Release imports the legacy store, the Sparkle feed path stays lowercase, Settings/setup use `PopUpPicker`, hosted tests skip live surfaces, Input Monitoring relaunch is a process argument.
- **Compiler**: Swift 6 complete concurrency checking, warnings as errors.

SwiftUI details the linter cannot see still follow the existing screens: extract `View` structs rather than computed-property subviews, prefer Dynamic Type over fixed font sizes, avoid hard-coded padding unless the design requires it, and put view logic in testable models. One type per file, grouped by feature.

## Product invariants CI cannot fully see

1. **Copy matches the UI that exists.** Do not name buttons, notices, or recovery paths that are not on screen. Prefer whole localized strings over fragments. User-facing strings live in `Resources/Localization` with manual keys (`Text(.key)`).
2. **Persistence fails closed.** Never delete, recreate, or substitute unreadable user data. Never import `Application Support/default.store` into a Debug identity. Leave mixed or foreign SwiftData stores alone.
3. **Physical Keyboard Identity** follows [`docs/choices.md`](docs/choices.md): serial number, else Bluetooth address, else vendor and product IDs (both nonzero). CoreHID software IDs are not identity. A changed identity never moves saved data, except the one-time built-in migration in ADR 0003.
4. **Do not merge Debug and Release identities** (ADR 0008). macOS keeps one Input Monitoring row per bundle ID; a shared ID has wiped grants and user data.
5. **Settings and Guided setup selectors** use `PopUpPicker` (`NSPopUpButton` + `.flexiblePush`). SwiftUI `Picker` and bordered `Menu` in a grouped `Form` hide the System Settings pop-up box at rest on macOS 26.
6. **Behavior changes** update `docs/choices.md` and `docs/testing.md` in the same PR, and add a regression that failed before the fix.
7. **Bot review comments are hints.** Verify each finding against the ADRs and `docs/choices.md` before applying it. Over-corrections (sticky shared identity, extra TCC confirmation, merging identities because “the mechanism is no longer needed”) have been rejected.

## Pull requests

- Conventional Commit titles in plain language: `fix(menu): keep scroll position when a keyboard reconnects`.
- One concern per PR. `./Scripts/run.sh test` must pass. If SwiftLint is installed, it must be clean.
- UI changes need before/after images; motion needs a short video. Do not commit PR-only assets.
- Never make a PR unless the developer asked. If the PR closes an issue, add `Closes #123`.

## Xcode MCP

If the Xcode MCP is configured, prefer its tools over generic alternatives: `DocumentationSearch`, `BuildProject`, `GetBuildLog`, `RenderPreview`, `XcodeListNavigatorIssues`, `ExecuteSnippet`, and `XcodeRead` / `XcodeWrite` / `XcodeUpdate` for project files.

## Agent skills

- Issues and specs: `docs/agents/issue-tracker.md`.
- Triage labels: `docs/agents/triage-labels.md`.
- Domain docs: `docs/agents/domain.md`.
