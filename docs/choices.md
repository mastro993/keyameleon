# Choices

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
