# Choices

## 2026-08-14 — Official Release workflow (grill)

### Defaults

- Start an Official Release only with `workflow_dispatch` on `main`. The workflow creates the annotated tag. Kill the tag-push trigger.
- Dispatch only when the chosen SHA is on `main`. `verify` waits for **Build and test** (45m). No feature-branch release.
- V1 has one Channel: Stable. Beta ignored. No in-app Channel picker. One Sparkle feed: `releases/latest/download/appcast.xml`.
- Tag stays `vMAJOR.MINOR.PATCH`. Dispatch `version` is SemVer core (`1.2.3`). Inject marketing and build numbers at Official Release build. Do not commit a version bump.
- Official Release is immutable. Fail if the tag already exists. Do not `--clobber` the zip.
- Homebrew descoped. No tap, no cask, no brew job. README stays zip primary, source-build secondary.
- Notes: `git log` since previous Official Release tag. Subjects only. No merge commits. No author names. No dispatch `notes`. First Official Release body starts with `Initial Official Release`. Empty range (new version, same commit): `No source changes since <previous tag>`.
- Same `main` SHA may receive a new Official Release version. Same version may not.
- Dispatch inputs: `version` only (SemVer core). `ref` is `main`.
- Environment `official-release` deployment branches: `main` (produce runs before the tag exists).
- Tag after artifacts. Notes from `official-release-notes.sh` before the new tag exists.
- Re-run of `produce` may finish a tag that has no GitHub Release. A new dispatch of the same version still fails if the tag exists.
- Reuse GitHub Environment `official-release`. Same secrets. Lead maintainer only until required reviewers exist.
- Local `SKIP_NOTARIZE=1` stays a non-Official path. No dispatch dry-run.
- Appcast is latest item only. No Sparkle deltas.

## 2026-08-14 — Issue #51 Complete accessible menu-bar panel

### Seams

- `MenuBarPanelAccessibility` — VoiceOver speech, keyboard focus order, overflow keyboard path. Tests live here.
- `MenuBarAssignmentList.Row` — one label (Physical Keyboard Name) + one value (Input Source, connection or Active, warning).
- `MenuBarPanelChrome` — Liquid Glass vs opaque (Reduce Transparency); rainbow vs high-contrast Active emphasis.
- `KeyameleonMenuBarPanelController` / `KeyameleonApplicationDelegate` — Escape and outside-click close the transient popover only.

### Defaults

- Keep shipped #50 surface: Keyboards + footer. Recovery and Pause/Resume stay in More. Cog remains Open Keyameleon (Quick Action).
- VoiceOver order: panel (Keyameleon + Switching Status), Keyboards heading, rows or empty state, Version, Open Keyameleon, More.
- Row speech: label = Physical Keyboard Name; value = `Italian, Active` / `US, Connected` / `French, Disconnected` plus warning once. Badge and warning symbol stay hidden.
- Version speech: label `Version`, value marketing number or `—`. Visible text stays `Keyameleon 0.1.0`.
- Keyboard Tab: assignment rows (read-only), then Open Keyameleon, then More. Pause/recovery/Settings/Quit via More menu.
- Open focuses a silent container (no ring). Tab moves to the first assignment or Open Keyameleon and shows the ring. Footer AppKit buttons become first responder only after Tab.
- Empty list: Tab starts at Open Keyameleon. Empty card is VoiceOver-only.
- Reduce Transparency → opaque `windowBackgroundColor` fill. No extra glass cards.
- Increased contrast → Active uses 2 pt accent stroke, not rainbow.
- Long Physical Keyboard Names wrap to 2 lines; Input Source stays 1 line. Full name stays in speech.
- Dismiss does not pause, resume, assign, or check again. Escape and outside-click use the same `performClose` path as `close()`. Tests cannot synthesize `NSEvent.keyEvent` (safety audit).

## 2026-08-14 — Release README audience and claims

### Defaults
- Public README is user-first: hook, install, use, privacy, then build / architecture / release / contribute.
- User is a person with multiple Physical Keyboards of different physical layouts. Not a language persona.
- No First-Key Guarantee in glossary, README, or UI. Activity-Triggered Switching is the named behavior.
- No user-persona glossary term. README uses prose only.
- Screenshot later at `assets/screenshot.png`: menu-bar icon + open panel, heading Keyboards, ≥2 assigned pills, one Active, Switching Status Ready.
- Install: Official Release zip primary. Source-build secondary. No Homebrew until a cask exists.
- Screenshot: placeholder + intended-shot description. No image file in this pass.
- Features: full user-visible surface, short bullets.
- Privacy: own README section.
- Maintainer block: build commands, short architecture, Official Release workflow + secrets table. Detail remains in `docs/release/official-release.md`.

## 2026-08-14 — Issue #50 Menu-bar Quick Actions, recovery banner, footer

### Seams

- `MenuBarPanelContent` — `MenuBarAssignmentList` plus footer. Overflow actions are typed here. Tests live here.
- `KeyameleonMenuBarPanelView` — renders keyboards and footer only.
- `MenuBarPanelContent.Action.closesPanel` — dismissal contract. View closes the popover before running a closing action.

### Defaults

- Panel body is Keyboards + footer. No Quick Actions row, recovery banner, or unclean-exit notice.
- Footer cog (`gearshape`) opens the main window (`Open Keyameleon`) and closes the panel. Incomplete setup continues there. No Continue Setup action.
- Overflow (ellipsis): Pause/Resume, recovery actions when Permission Required or Temporarily Unavailable offers them, Check for Updates…, Settings…, Quit Keyameleon. Diagnostics stay in the main window only.
- Pause / Resume and Check Again / Dismiss keep the panel open. Other overflow actions close it.
- Footer left: `Keyameleon <marketing>` from `CFBundleShortVersionString`. No build number. Blank or missing → `Keyameleon —`.
- Footer is its own full-width container. 1 pt `.separator` top border. List bottom pad 4, footer top pad 6.
- Footer right: two small `.circular` icon buttons. Cog a11y is `Open Keyameleon`. Ellipsis a11y is `More`.
- Overflow control is an AppKit `NSButton` + `NSMenu`. Do not add `sizeThatFits` — the safety audit treats `CGSize` as a forbidden `CGS*` surface. SwiftUI `Menu` inside the transient popover is not in the XCUITest tree.
- Click away from More cancels menu tracking and closes the panel. `NSMenu.popUp` would otherwise eat the click the transient popover needs.
- Panel order: Keyboards, footer.

## 2026-08-14 — Menu-bar assignment pills

### Seams
- `MenuBarAssignmentList.Row` — title (Physical Keyboard Name), subtitle (assigned Input Source), `isActive`. No trailing value.
- `MenuBarAssignmentPill` — white squircle pill; Active = 2 pt angular rainbow border + soft neutral badge at top right.
- `MenuBarAssignmentRows` — `LazyVStack`; viewport still `visibleRowLimit == 5`; no data cap.

### Defaults
- Squircle = `RoundedRectangle(cornerRadius: 16, style: .continuous)`.
- Theme-aware control background stays opaque for all pills. Active adds the rainbow border and a soft neutral `Active` badge. Text uses primary and secondary system styles.
- Disconnected content stays 0.5 opacity without dimming the adaptive background. Rows stay read-only.
- More than five pills: assignment area scrolls. Actions stay fixed.

## 2026-08-14 — Request Permission no-op

### Seams
- `NSInputMonitoringUsageDescription` in `Info.plist` / `project.yml` — required for `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` to show the Input Monitoring prompt.
- `KeyameleonSetupModel.requestPermission()` — Guided setup action: request listen permission, then open System Settings only if Switching Status stays Permission Required.
- `SystemListenPermissionProvider.requestListenPermission()` — activate the accessory app before `IOHIDRequestAccess`.

### Defaults
- Request Permission on Guided setup uses `SetupModel.requestPermission()`, not the switching module alone.
- Denied or already-denied requests open Privacy → Input Monitoring. Granted requests do not.
- Usage description names Activation Activity and Activity-Triggered Switching. No Key Content claim.

## 2026-08-14 — Issue #49 Assigned Physical Keyboards in menu-bar panel

### Seams

- `MenuBarAssignmentList` — pure presentation: assigned-only filter, Active/connected/disconnected order, row marks, Unavailable Keyboard Assignment copy, empty state, scroll boundary (`visibleRowLimit == 5`).
- `MenuBarPanelContent` — still owns remaining Menu first notices and actions; embeds one `MenuBarAssignmentList`.
- `MenuBarAssignmentSection` / `MenuBarAssignmentRowView` — render typed rows only. Rows are not buttons.

### Defaults

- Reuse `PhysicalKeyboardListOrdering` (Active, other connected, disconnected; alphabetical Physical Keyboard Name inside each group).
- A Keyboard Assignment is `assignmentState == .assigned`. Unassigned and unsupported Physical Keyboards stay out of the list.
- Resolved Input Source name when eligible catalog has it. Otherwise second line is `Unavailable Input Source` plus warning symbol and note `Unavailable Keyboard Assignment`.
- Heading is `Keyboards`. No app-name header. No assignment count.
- Empty state uses a theme-aware soft gray keyboard card: `No assigned keyboards` and `Open Keyameleon Settings to assign keyboards.` Open Settings stays in the existing action list.
- Distinct accessible marks: Active, Connected, Disconnected. Disconnected rows use 0.5 opacity.
- More than five rows: assignment area scrolls; actions stay outside the scroll view.
- Keep Switching Status, Temporarily Unavailable copy, unclean-exit notice, and current actions until #50 replaces them.
- When `outcome` has `.requestPermission`, panel shows **Request Permission** next to Switching Status. Action calls `SetupModel.requestPermission()`.
- Panel order: Keyboards first, then Switching Status / diagnostics notices, then actions.
- Drop Active Physical Keyboard / Keyboard Assignment / Current Input Source / mismatch / Needs action status lines. The assignment list replaces that dump.

## 2026-08-13 — Issue #48 Live Liquid Glass menu-bar panel

### Seams

- `KeyameleonMenuBarPanelController` — one AppKit module: show, toggle, and close one transient 320 pt `NSPopover` anchored to the existing `NSStatusItem` button. Refresh runs before presentation.
- `MenuBarPanelContent` — typed Menu first rows and actions. `KeyameleonMenuBarPanelView` renders that content on one native popover glass surface.
- `NSStatusItem` stays the durable menu-bar lifecycle. Icon marks and accessibility descriptions stay on the status-item button.

### Defaults

- Keep AppKit `NSStatusItem`. Do not switch to `MenuBarExtra`.
- Replace `NSMenu` with one `NSPopover` (`behavior = .transient`, `animates = false`) so click-outside and Escape close the panel. Close stays synchronous for tests and status-item toggle.
- Native Liquid Glass comes from the macOS 26 popover chrome. Do not wrap the panel or its sections in extra `glassEffect` / `NSGlassEffectView` cards.
- Opening the panel calls `ActivityTriggeredSwitching.checkAgain()` before show, then refreshes the status-item icon. That refreshes permission, observed Input Source, Keyboard Assignments, and Switching Status. Physical Keyboard list stays live through existing discovery observation.
- Status-item toggle ignores a show that would land within 250 ms of a transient close, so the same click cannot close and reopen the panel.
- Current Menu first rows and actions stay functional in the panel until #49/#50 replace that content.
- Cmd+Q and Settings shortcuts live on the panel actions. UI tests click panel buttons, not `statusItem.menuItems`.

## 2026-08-13 — Debug Run package resolve / legacy build locations

### Defaults
- Shared workspace settings use `BuildLocationStyle=UseAppPreferences` and `DerivedDataLocationStyle=Default`.
- `./Scripts/run.sh generate` rewrites those shared settings and changes user `UseTargetSettings` to `UseAppPreferences`.
- Sparkle stays a remote Swift package. No vendor, no exact-version pin for this fix.

## 2026-08-11 — Product validation and macOS 26 support

### Defaults
- This supersedes the qualification-process defaults recorded under Issues #17 and #19 below.
- Supported Release targets macOS 26.
- Pull requests run one focused product test suite with one fast safety audit.
- Monitor-only behavior and no saved Key Content remain hard failures.
- Repeated suites, fixed stress counts, human qualification matrices, qualification evidence files, and performance quotas are removed.

## 2026-08-11 — Issue #39 Activity-Triggered Switching module

### Seams

- `ActivityTriggeredSwitching` is the one concrete observable switching module. Its external surface is one immutable `ActivityTriggeredSwitchingOutcome` and seven product operations: start, stop, request permission, check again, pause, resume, and retry now.
- `PhysicalKeyboardDiscovery`, `InputSourceModule`, `PhysicalKeyboardRecordStoring`, and `OperationalNotifications` keep discovery, exact selection, record changes, and notification episodes local to their own deep modules.
- SetupModel owns Guided setup and Physical Keyboard management. RootView and Daily Status consume the switching outcome directly.

### Defaults

- Internal identifiers, wanted generations, selection request evidence, warning episode evidence, raw Physical Keyboard Events, and lifecycle adapter facts do not cross the product outcome.
- The production factory creates one shared discovery, Input Source, and Operational Notification module for the application lifetime.
- Focused tests use deterministic adapters and assert the product outcome plus internal adapter evidence.

## 2026-08-10 — Issue #19 Setup and accessibility qualification

### Seams under test
- `Scripts/qualify-setup-accessibility.py` — automated source audit, application build, complete test suite, and privacy-safe human evidence verdict.
- SwiftUI accessibility identifiers and grouped status values — stable discovery points for Guided setup and accessibility qualification.
- `KeyameleonLifecycleUITests` — first launch, close, reopen, menu actions, and quit lifecycle.

### Defaults
- Qualify every required setup and accessibility case on macOS 15 and macOS 26.
- Bind each report to the candidate source commit and keep source, build, and test gates separate from human evidence.
- Treat unavailable or unrun required cases as `inconclusive`; a candidate passes only when every gate passes.
- Keep `evidenceRef` and aggregate measurements only. Do not store Key Content, stable Physical Keyboard Identity or Input Source values, or participant identity.
- Keep Manual Physical Keyboard Designation outside the timed Guided setup journey.

## 2026-08-10 — Issue #12 Bounded operational notifications

### Seams under test
- `OperationalNotificationProviding` — alert authorization state, explicit alert request, and operational notification delivery.
- `OperationalNotificationEpisodeStoring` — persistent episode, sent, and recovery state.
- `NotificationSetupDecisionStoring` — one optional setup offer after the first Keyboard Assignment.
- `NotificationSettingsOpening` — General Settings access to notification settings.
- `KeyameleonSetupModel` — permission and Unavailable Keyboard Assignment episode boundaries.

### Defaults
- Request authorization only after an explicit Enable Operational Notifications action.
- Request `.alert` only. Do not request sound or icon badge access.
- Send only for revoked listen permission and a newly Unavailable Keyboard Assignment.
- Persist hashed episode tokens and sent state. Keep exact Physical Keyboard Identity and Input Source identifiers out of UserDefaults.
- Mark an episode sent before delivery. Recovery removes its sent state so a later recurrence can send once.
- Pause suppresses delivery. Notification denial never changes Activity-Triggered Switching.
- General Settings shows the current authorization state and opens System Settings without requesting again.

## 2026-08-10 — Issue #16 Official Release artifacts

### Seams under test
- `KeyameleonReleasePolicy` — Official Release tag shape (`vMAJOR.MINOR.PATCH`), artifact names, `GPL-3.0-only`, Supported Release = latest only.
- `KeyameleonReleaseEvidence` — JSON binding artifact SHA-256 + source tag/commit; reject bad tag/hash.

### Defaults
- Tag-only Official Release workflow (`v[0-9]+.[0-9]+.[0-9]+`); no branch push release.
- GitHub Environment `official-release` for the produce job; required reviewers documented (plan may block API enablement on private free tier).
- Secrets: Developer ID p12, notarytool API key, Sparkle EdDSA private+public — env/repo secrets only; `.gitignore` for local key material + `dist/`.
- Sparkle public key injected at Official Release build (`SUPublicEDKey`); debug builds may omit (existing #15 behavior).
- Artifacts on one GitHub Releases channel: zip, source tar.gz, `appcast.xml`, `release-evidence.json`.
- CI required checks documented for `main` protection.
- `SKIP_NOTARIZE=1` local path is not an Official Release.

## 2026-08-10 — Issue #13 Diagnostic Data + Diagnostic Sessions

### Seams under test
- **Domain pure** (`KeyameleonDiagnosticData`): closed allowlist categories/codes, session max 10m, retention 7d/5MB oldest-first, temporary Physical Keyboard tokens, estimated record size.
- **`DiagnosticDataControlling`**: start/stop session, auto-expire, record allowlisted operational/session events, clear all, delete by Physical Keyboard identity linkage, retention prune, read records.
- **`ClockProviding`**: time boundary for session + retention.
- **`KeyameleonSetupModel.forgetPhysicalKeyboard`**: also deletes Diagnostic Data linked to that Physical Keyboard.
- **`KeyameleonGeneralSettingsModel`**: Diagnostics section (session + clear).

### Defaults
- Typed API only — no free-form String payload path into Diagnostic Data.
- Default recording: operational errors + state changes. Not one record per Physical Keyboard Event.
- Diagnostic Session unlocks detailed allowlisted categories (observation order, Input Source selection result, relative timing) still without Key Content or identity values.
- Physical Keyboard linkage: SHA-256 of identity key → temporary UUID token (no exact identity/serial in Diagnostic Data store). Records store token only.
- Size retention uses fixed `estimatedBytesPerRecord` (closed schema; not on-disk measurement).
- Separate SwiftData container for Diagnostic Data (no PK schema migration risk).
- Session auto-stop checked on access/record + MainActor timer while active.
- Forget confirmation copy includes Diagnostic Data removal.
- UI: General Settings → Diagnostics (start/stop session, clear all). Diagnostic Bundle review, save, and share is #14.

## 2026-08-10 — Issue #14 Review, save, and share Diagnostic Bundles

### Seams under test
- **`DiagnosticBundleBuilder`**: stable JSON export from the closed Diagnostic Data schema, with category, date range, count, size, and exclusion summary.
- **`KeyameleonDiagnosticBundleReviewView`**: Guided setup and General Settings review surface with explicit Save and Share actions.
- **`UserDefaultsUncleanExitStateStore`**: local active-launch marker and one dismissible Menu first notice after an unclean exit.

### Defaults
- Save uses SwiftUI `fileExporter` so the user selects the destination.
- Share uses SwiftUI `ShareLink` and the macOS share interface.
- Bundle records contain only closed allowlist fields and temporary Physical Keyboard tokens; no Physical Keyboard Identity, Key Content, crash report, or path data.
- The unclean-exit notice is local, sends no notification, and clears only after Review Diagnostics… or Dismiss Diagnostics Notice.
- Controlled sensitive sentinels are tested as absent from generated bundles.

## 2026-08-10 — Issue #10 selection failure + Unavailable Keyboard Assignment seams

- **Domain pure**: `SwitchingWarning`, `SwitchingFailureCategory`, `SwitchingRecoveryAction`, `WantedKeyboardAssignment`, `KeyboardAssignmentAvailability` (exact identifier only).
- **Recovery coordinator** on `KeyameleonSetupModel`: one warning per active cause, `retryNow()`, skip select for unavailable, reevaluate on Input Source refresh.
- **Converge integration**: keep wanted generation + generation-gated readback from #6; `WantedKeyboardAssignment` adds Physical Keyboard ID for Retry Now.
- **InputSourceSelecting** unchanged: restore prior Input Source on exact readback mismatch.

Defaults:

- Selection failure cause is singular (current wanted). Newer assigned Activation Activity replaces wanted + may reselect.
- Unavailable cause is per Physical Keyboard Record ID. Saved assignment stays; no substitute select.
- Exact eligible-identifier return clears unavailable only. No timed retry loop.
- `warningEpisodeCount` increments only when a new cause becomes active.
- UI: plain category + recovery copy + **Retry Now** for selection failure; Change/Remove already on keyboard row.

## 2026-08-10 — Issue #9 Manual Physical Keyboard Designation

### Seams under test
- `ManualPhysicalKeyboardDesignationEvidenceRules` — offer eligibility + return accept + confirmed name.
- `ManualPhysicalKeyboardDesignationAuthenticator` — CryptoKit HMAC over identityKey/productName/confirmedName only (no Key Content).
- `InstallationIntegrityKeyProviding` — Keychain-backed SymmetricKey (in-memory for tests).
- `ManualPhysicalKeyboardDesignationStoring` — authenticated evidence persistence (SwiftData + in-memory).
- `KeyameleonSetupModel` session: start → leave → return → confirm name; other Physical Keyboards stay assignable.

### Defaults
- Eligible only: external, identity-based, `.unsupported(.ambiguousIdentity)`. Missing/unstable/shared never offered.
- Ambiguous multi-interface return still valid (approved exceptional case). Shared/unstable/missing return not accepted.
- Save name + designation evidence only; no Keyboard Assignment from the flow.
- Integrity key: Keychain generic password, service `dev.fedemas.keyameleon.installation-integrity`.
- Designation model lives in `PhysicalKeyboardSchemaV1` container (additive model). Tampered HMAC → stay unsupported.
- Identity change: no auto migrate/delete of designation or records.
- Forget deletes designation for that identityKey.

## 2026-08-10 — Issue #7 Menu first + pause

- **Pause persist**: `SetupDecisionStoring.isActivityTriggeredSwitchingPaused` / UserDefaults key `keyameleon.activityTriggeredSwitching.paused`.
- **Status resolve**: pure `SwitchingStatus.resolve` priority Permission Required → Temporarily Unavailable → Paused → Ready.
- **Discovery vs observe**: Paused keeps Physical Keyboard discovery for management; stops Key Content observation + Input Source requests (`allowsPhysicalKeyboardDiscovery` vs `allowsActivityTriggeredSwitching`).
- **Temp unavailable**: flag slot on SetupModel for #11; no sleep/lock wiring in #7.
- **Menu bar icon**: SF Symbol shapes per `MenuBarIconMark` (not color-only). Item warning only when Ready.
- **Menu first action items**: unassigned + Unavailable Keyboard Assignment lines; incomplete setup still uses Continue Setup….
- **Resume**: clear pause → recheck listen permission → start observation only if Ready.

## 2026-08-10

### Issue #6 Converge after rapid activity and external changes

Seams under test:
- `KeyameleonSetupModel.handlePhysicalKeyboardEvent` — serial activity consumer (observation order).
- Wanted Keyboard Assignment generation on `KeyameleonSetupModel` — bump per select need; discard stale readback.
- `InputSourceChangeObserving` — external Input Source changes (manual / shortcut / other apps).
- `activeInputSourceMismatch` presentation — current vs assigned when they differ.
- `KeyameleonAppMetadata` restore copy.

Defaults:
- Sync TIS select still generation-gated so nested/reentrant activity cannot apply stale verify.
- External change: update observed current, clear verified when current ≠ verified, never select.
- Coalesce only when wanted + verified + current all match the assignment.
- UI/Menu first show current + assigned names + restore explanation only on mismatch for Active assigned keyboard.
- System observer: `DistributedNotificationCenter` + `kTISNotifySelectedKeyboardInputSourceChanged`.

### Issue #5 Activity-Triggered Switching seams

- **Activation Activity classification** (domain pure): `PhysicalKeyboardEventKind` press/repeat/release; release not Activation Activity.
- **Switching coordinator** via `KeyameleonSetupModel`: Active Physical Keyboard, request exact Keyboard Assignment, exact identifier readback.
- **Input Source select/verify** protocol: `InputSourceSelecting` (TIS boundary).
- **Event observe** protocol: `PhysicalKeyboardEventObserving` (CoreHID listen-only; no seize).
- **Catalog**: serviceID → Physical Keyboard for attribution.

Defaults:

- Coalesce select when wanted assignment already verified active (story 57 minimal).
- Failures leave input unchanged (restore prior Input Source on readback mismatch); no toast (#5); no retry loop.
- Active Physical Keyboard not persisted across restart.
- Lifecycle list merge from #8 stays authoritative in `publishPhysicalKeyboards`.

## 2026-08-10 — Issue #15 Launch at Login + updates

### Seams under test
- `LaunchAtLoginControlling` — enable/disable Launch at Login; `ServiceManagement` adapter uses `SMAppService.mainApp` (no login helper).
- `UpdateChecking` — start on launch + manual check; Sparkle adapter only.
- `KeyameleonUpdatePolicy` — pure constants for 24h interval, no auto-install, no system profile, no Keyameleon-generated identifiers.
- `KeyameleonGeneralSettingsModel` — General settings presentation over those seams.
- `KeyameleonAppMetadata` — user-visible General / Launch at Login / update strings.

### Defaults
- Sparkle Info.plist: automatic checks on, interval 86400s, automatic download/install off, automatic-update option disallowed, system profiling off.
- Feed URL: `https://github.com/mastro993/Keyameleon/releases/latest/download/appcast.xml` (Official Release issue owns appcast + EdDSA key).
- `SUPublicEDKey` omitted until release tooling supplies it; updater start failures stay non-fatal so debug builds still launch (explicit exception to fail-loud until Official Release keys exist).
- Critical-update warning: Sparkle standard user driver + General settings copy; `SUAllowsAutomaticUpdates=false` so critical never auto-installs.
- General Settings: Launch at Login toggle + Check for Updates… + short critical-update warning copy.
- Menu first: Settings… and Check for Updates… entries.
- Dropped `SYMROOT` (blocks SPM); `Scripts/run.sh` uses `-derivedDataPath build`.

## 2026-08-10 — Issue #8 Physical Keyboard lifecycle

- **Seams under test**: `PhysicalKeyboardRecordStoring` and `KeyameleonSetupModel` (application-service seam from parent #1). Catalog unit rules stay in domain tests.
- **Active Physical Keyboard**: in-memory only on `KeyameleonSetupModel`; not persisted across app restart. `noteActivationActivity` remains a test/manual seam; real switching uses `handlePhysicalKeyboardEvent`. Lifecycle slice never increments Input Source selection requests.
- **Disconnected list merge**: saved SwiftData records whose identity is not in the live catalog publish as `connectionState == .disconnected`. Catalog still drops disconnected HID services.
- **Replace**: explicit model API + confirmation UI; candidates are disconnected saved identity-based records only.
- **Forget**: deletes store record only. Connected hardware republishes as new unassigned from catalog; disconnected vanishes.
- **Schema**: keep PhysicalKeyboardSchemaV1. No new columns; disconnected rows reuse productName + assignment + identityKey. Transport for disconnected-only rows is `.other`.

## 2026-08-11 — Issue #41 Local presentation ownership

### Seams under test
- AppKit menu and icon presentation — menu titles, order, accessibility values, status symbols, and unclean-exit actions.
- SwiftUI presentation owners — Guided setup, Physical Keyboard configuration, General Settings, and Diagnostic Bundle review copy.
- Typed domain and model facts — switching conditions, Physical Keyboard conditions, Input Source mismatches, and Launch at Login errors.
- Independent UI-test contracts — bundle identity, accessibility identifiers, launch arguments, and externally visible copy.

### Defaults
- `KeyameleonAppMetadata` is deleted. No replacement registry, copy enum, or string-only file is added.
- Each implementation owns its user-visible copy and private formatters. Duplicate copy remains local when presentation owners happen to share text.
- Domain and model interfaces expose typed facts or domain data. Physical Keyboard Names, Input Source names, persisted codes, and Diagnostic Bundle exclusion labels remain domain-owned.
- `SwitchingStatus.rawValue` values stay unchanged because Diagnostic Data persists them.
- Runtime application identity comes from the application bundle. Published product and artifact identity remains deterministic in `KeyameleonReleasePolicy`.
- UI tests keep independent expected literals. Production accessibility identifiers and launch arguments remain unchanged.
- Earlier choices that named `KeyameleonAppMetadata` are superseded for ownership only; their external values and behavior remain unchanged.
