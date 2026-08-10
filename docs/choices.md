# Choices

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
- DCO required via workflow + CONTRIBUTING; CI required checks documented for `main` protection.
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
- UI: General Settings → Diagnostics (start/stop session, clear all). Bundle export is #14.

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
