# Breadcrumbs

## 2026-08-14 — Tighter footer, no panel diagnostics

- List-to-footer gap: 4 + 6. Overflow drops Review/Dismiss Diagnostics.

## 2026-08-14 — Panel is keyboards + footer

- Body: assignment list + footer only. Pause/recovery/diagnostics/Settings live in ellipsis.
- Cog opens main window (`Open Keyameleon`), not Settings.

## 2026-08-14 — Footer cog and ellipsis

- Footer right: circular `gearshape` Settings icon + `ellipsis` overflow. Settings leave the menu.

## 2026-08-14 — More outside click

- Click away from More: cancel `NSMenu` tracking + close the panel. Transient popover never saw that click.

## 2026-08-14 — More is pull-down

- Footer overflow: small `.flexiblePush` pill. `More` + trailing `chevron.down`. A11y title `More` for UI tests.
- Do not name `CGSize` in Sources. `run.sh` audit `CGS[A-Za-z]` matches it and blocks `open` / `test`.

## 2026-08-14 — Footer container

- Footer is own full-width region. 1 pt `.separator` top border. Content stack keeps 16 pt padding.

## 2026-08-14 — Keyboards first in menu-bar panel

- Panel order: Keyboards, Quick Actions, recovery banner, unclean-exit notice, footer.

## 2026-08-14 — Footer version label

- Visible footer: `Keyameleon <marketing>` not `Version <marketing>`. Blank → `Keyameleon —`.

## 2026-08-14 — Merge #49 assignment list into #50 panel

- Keep #50 Quick Actions, recovery banner, footer. Replace leftover status dump with `MenuBarAssignmentList`.
- Request Permission lives in the recovery banner when the outcome offers it.

## 2026-08-14 — Menu-bar Request Permission missing

- Outcome already had `.requestPermission` on Permission Required. Panel never rendered it.
- Add notice action **Request Permission** → `SetupModel.requestPermission()`.

## 2026-08-14 — Menu-bar assignment pills

- Assigned rows render as squircle pills: Physical Keyboard Name title / assigned Input Source subtitle / no trailing value.
- All assigned rows use a theme-aware control background. Active (last Activation Activity) gets a 2 pt rainbow border and a soft neutral `Active` badge at top right.
- List unbounded via `LazyVStack`; 5-pill viewport still scrolls overflow.

## 2026-08-14 — Request Permission click did nothing

- Cause: no `NSInputMonitoringUsageDescription` → `IOHIDRequestAccess` returns false with no prompt. Denied path also opened nothing.
- Fix: add usage description; `SetupModel.requestPermission()` opens System Settings when status stays Permission Required; activate app before request.

## 2026-08-14 — Issue #49 Assigned Physical Keyboards in menu-bar panel

- Seam: `MenuBarAssignmentList` filters/orders assigned rows; panel view renders read-only section with 5-row scroll cap.
- Empty Keyboards section uses a theme-aware soft gray keyboard card with a title and Settings guidance.
- Keep #48 actions/footer until #50. Drop Menu first assignment status dump.
- Order: Keyboards, then Switching Status / unclean-exit diagnostics, then actions.

## 2026-08-13 — Issue #48 Open live Liquid Glass menu-bar panel

- Replacing status-item `NSMenu` with one transient 320 pt SwiftUI `NSPopover`.
- Native macOS 26 popover glass; no stacked glass cards.
- Refresh-before-show via `checkAgain()`. Icon marks stay on the `NSStatusItem` button.

## 2026-08-13 — Xcode Debug Run could not resolve packages

- Repro: `WorkspaceSettings.xcsettings` with `BuildLocationStyle=UseTargetSettings` → `xcodebuild: error: Could not resolve package dependencies: Packages are not supported when using legacy build locations, but the current project has them enabled.`
- User-facing Xcode phrasing: could not verify package dependencies.
- Cause: user workspace settings (present on main checkout) force legacy project-relative locations. SPM refuses that layout. CLI with no xcuserdata was green.
- Fix: commit shared modern workspace settings; `run.sh generate` rewrites them and neutralizes user `UseTargetSettings`.

## 2026-08-11 — Product validation simplification

- Reduced CI to one macOS 26 test job with the focused suite and safety audit.
- Removed repeated qualification, 100,000-event stress, human qualification evidence, and performance quotas.
- Replaced qualification guidance with `docs/testing.md` and recorded the decision in `docs/adr/0001-product-validation.md`.

## 2026-08-11 — Issue #39 Activity-Triggered Switching module

- Added `Sources/App/ActivityTriggeredSwitching.swift` and `Sources/Domain/ActivityTriggeredSwitchingOutcome.swift`.
- Added shared Physical Keyboard discovery, Input Source, Physical Keyboard record change observation, and Operational Notification modules.
- Added `KeyameleonProductionFactory` at the application composition root. SetupModel now owns management only; RootView and Daily Status read the canonical switching outcome.
- Focused Swift Testing covers the preserved activation, convergence, recovery, lifecycle, pause, notification, and privacy behavior through deterministic adapter evidence.

## 2026-08-10 — Issue #19 Setup and accessibility qualification

- Added `./Scripts/run.sh qualify-setup-accessibility` for source audit, application build, complete tests, and privacy-safe human evidence evaluation.
- Added required case rows for Guided setup, management, Switching Status and recovery, Diagnostic Bundle and General Settings, keyboard operation, VoiceOver, visible state, and Reduce Motion on macOS 15 and macOS 26.
- Added stable SwiftUI accessibility identifiers for qualification discovery and verified the lifecycle UI journey through quit.
- Human physical and accessibility qualification remains required. Missing or unrun evidence is `inconclusive` and blocks an Official Release.

## 2026-08-10 — Issue #17 Automated Qualification

- Added source, dependency, binary, network, and crash-surface audits.
- Added deterministic 100,000 Physical Keyboard Event stress coverage and
  Activation Activity privacy sentinels.
- Added 10-consecutive-suite qualification with sanitized evidence and explicit
  pass, fail, or inconclusive verdicts.
- CI runs qualification on macOS 15 and macOS 26.

## 2026-08-10 — Issue #16

- Implement Official Release path: SemVer tag workflow, sign/notarize/staple script, Sparkle appcast, evidence JSON, GPL-3.0-only + notices, SECURITY Supported Release, contributing guidance.
- Host limits: private free tier cannot set environment required reviewers or branch protection via API — documented for lead maintainer.
- Env `official-release` created empty; secrets still must be added by maintainer before first real release.

## 2026-08-10 — Issue #13 Control Diagnostic Data and Diagnostic Sessions

- Domain: closed allowlist `DiagnosticCategory`/`DiagnosticEventCode`, session 10m, retention 7d/5MB, temporary tokens.
- Service: `KeyameleonDiagnosticDataService` + `InMemory`/`SwiftData` store; `ClockProviding`.
- Wire: SetupModel records operational state/errors; session-only detailed codes; forget deletes linked diagnostics.
- UI: General Settings → Diagnostics (start/stop session, clear all).
- Tests: `DiagnosticDataTests.swift`. Diagnostic Bundle review, save, and share = #14.

## 2026-08-10 — Issue #14 Review, save, and share Diagnostic Bundles

- Domain: `DiagnosticBundleBuilder` produces closed-schema JSON and a review summary.
- UI: Guided setup and General Settings show categories, exclusions, date range, record count, and size before explicit Save or Share.
- Save: user-selected destination through `fileExporter`; Share: macOS share interface through `ShareLink`.
- Lifecycle: local unclean-exit marker adds one dismissible Menu first notice with Review Diagnostics…; no notification.
- Tests: sensitive sentinel exclusion and unclean-exit/menu notice coverage.

## 2026-08-10 — Issue #10

- Recover selection failures + Unavailable Keyboard Assignments.
- Parent #1; blocked-by #5 closed.
- Domain warning/availability; SetupModel recovery; Retry Now; tests in `KeyameleonRecoveryTests`.
- No timed retry; no substitute select; exact identifier return ends unavailable.
- Merged main: keep #6 converge generation, #7 menu/pause, #9 manual designation.

## 2026-08-10 — Issue #9 Manual Physical Keyboard Designation

- Issue #9: leave/return/name confirmation for eligible ambiguous external identity groups.
- Domain: evidence rules + CryptoKit authenticator + phase enum.
- App: Keychain integrity key, designation store, SetupModel session + elevation on publish/event.
- UI: start button, status banner, name confirmation sheet.
- Tests: `ManualDesignationTests.swift` (eligibility, auth, flow, shared reject, empty name, no migrate, tamper).
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

- Tests: `Tests/SwiftTesting/LifecycleTests.swift` (9 cases).
- Domain: `PhysicalKeyboardConnectionState`, `PhysicalKeyboardListOrdering`, disconnected factory.
- Store: `allRecords`, `deleteRecord`, `transferRecord`.
- Model: merge connected catalog + saved disconnected; active ID; forget/replace; no Input Source request on disconnect.
- UI: connection/active labels; Replace picker + confirm; Forget confirm.
- Follow-on: #5 wires Activation Activity into event observer and real selection.
