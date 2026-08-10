# Choices

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
