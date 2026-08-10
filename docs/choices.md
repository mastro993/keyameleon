# Choices

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

## 2026-08-10

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
