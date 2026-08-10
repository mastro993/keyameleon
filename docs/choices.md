# Choices

## 2026-08-10

### Issue #8 — Physical Keyboard lifecycle

- **Seams under test**: `PhysicalKeyboardRecordStoring` and `KeyameleonSetupModel` (application-service seam from parent #1). Catalog unit rules stay in domain tests.
- **Active Physical Keyboard**: in-memory only on `KeyameleonSetupModel`; not persisted across app restart. `noteActivationActivity` is the seam for later Activity-Triggered Switching (#5). Lifecycle slice never increments Input Source selection requests.
- **Disconnected list merge**: saved SwiftData records whose identity is not in the live catalog publish as `connectionState == .disconnected`. Catalog still drops disconnected HID services.
- **Replace**: explicit model API + confirmation UI; candidates are disconnected saved identity-based records only.
- **Forget**: deletes store record only. Connected hardware republishes as new unassigned from catalog; disconnected vanishes.
- **Schema**: keep PhysicalKeyboardSchemaV1. No new columns; disconnected rows reuse productName + assignment + identityKey. Transport for disconnected-only rows is `.other`.
