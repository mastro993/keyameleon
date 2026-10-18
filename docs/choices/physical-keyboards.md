# Physical Keyboards

## Recognition

Keyameleon inspects every CoreHID device, because keyboard collections can sit behind a pointer or vendor-defined primary usage. A device is a **Physical Keyboard** when it can produce **Activation Activity**: its primary or device usages include keyboard, keypad, or consumer (media key) usage, or it exposes a keyboard, keypad, or consumer input element. Recognition and Activation Activity observation share one element rule, so any device that can switch layouts is listed. LED output is not required, and pointer usage does not disqualify a device.

This broad rule prefers listing too many devices over missing a keyboard, such as a 2.4 GHz receiver whose keyboard collection is not advertised. The cost is listing some devices that are not keyboards, such as a mouse with shortcut buttons, a headset with volume buttons, or a display with media controls. The person ignores those (see [Ignoring devices](#ignoring-devices)) rather than Keyameleon guessing.

Recognition is separate from assignment: a device can be recognized without being assignable. Unsupported devices stay out of the keyboard list in Guided setup and Settings; a collapsed, read-only `Unsupported devices` section below the list shows each one's name, connection type and status, and reason. They cannot be renamed or ignored there.

## Identity

A **Keyboard Assignment** requires a stable, unique **Physical Keyboard Identity**.

- **External keyboards** use their USB serial number, or for Bluetooth LE keyboards without one, their Bluetooth device address. A device with neither, such as a 2.4 GHz receiver, falls back to its vendor and product IDs, so every HID interface of the receiver forms one row that survives reconnects and port changes. CoreHID's software IDs change on reconnect and differ per interface, so they are not used for these fallbacks.
- The vendor and product fallback names a model, not one device. When more than one serial-less device of the same model is connected at once (seen as different USB `locationID`s), they share one entry marked unsupported as `Shared ID` rather than Keyameleon guessing which is which.
- A keyboard without any stable, unique identity, including one whose vendor or product ID is zero, is unsupported and appears only under `Unsupported devices`, with the reason shown.
- **The built-in keyboard** is one fixed identity covering every CoreHID service macOS marks as built-in, independent of software or hardware identifiers ([ADR 0003](../adr/0003-built-in-physical-keyboard-identity.md)). Its default name is the shared macOS product name, or `Built-in Keyboard` when services disagree.
- When an identity changes, Keyameleon does not move or delete saved names, assignments, or designations automatically. The one exception is the one-time built-in migration in ADR 0003.

## Saved manual designations

Earlier versions let the person create a **Manual Physical Keyboard Designation**, and Replace or Forget a saved keyboard. Settings no longer offers any of the three, and Keyameleon no longer creates, moves, or deletes designations or saved keyboards.

- A designation saved by an earlier version still counts. It vouches for an external keyboard whose identity is ambiguous across interfaces and gives it the confirmed name; it never carries an assignment. Its evidence is authenticated with an HMAC (CryptoKit) whose key lives in the Keychain item `dev.fedemas.keyameleon.installation-integrity`. Tampered evidence leaves the device unsupported.
- A saved keyboard that is disconnected stays in the list with its name and assignment. Ignore hides it.

## Ignoring devices

A **Physical Keyboard Exclusion** (shown as **Ignore** in the UI) marks a device as not a keyboard.

- It is keyed by the device rather than a CoreHID service: the identity value without its anchor, or the vendor, product, and model when there is no identity. The built-in keyboard has no key, so it can never be ignored, even by a stale saved value.
- Ignoring is a filter, not a deletion. The saved name, assignment, and designation survive and come back on Stop Ignoring.
- An ignored device produces no Activation Activity, never becomes the Active Physical Keyboard, raises no warning, and cannot be retried; ignoring clears any pending assignment and selection warning for it.
- It persists across disconnect, restart, and the catalog reset that sleep, lock, and pause perform. Nothing removes it automatically, because every disconnect signal also fires for sleep, lock, and pause.
- Exclusions are stored as JSON in UserDefaults under `keyameleon.excludedPhysicalKeyboards`, so the SwiftData schema did not change.

## Lists and naming

- Guided setup and Settings share one keyboard list (`PhysicalKeyboardRows`) and row view. Ignored keyboards stay in place, dimmed, with their saved Input Source shown in a disabled picker.
- The built-in keyboard is always first, even when it is discovered after other rows. Other rows keep their order and identity for the session; new keyboards are appended.
- A row shows the **Physical Keyboard Name** (the custom name, or the product name) and its connection status: `Connected` or `Disconnected`, prefixed by `<product> · ` when a custom name hides the product name, with ` (Ignored)` appended for ignored rows.
- Pickers show `Unassigned` when there is no assignment. Missing or ambiguous saved records show a disabled `Unassigned` picker rather than an assignment borrowed from another record.
- The row's trailing menu offers **Rename…** (when the identity is safe) and **Ignore**, or **Rename…** and **Stop Ignoring** for an exact ignored record. Missing or ambiguous ignored records offer only Stop Ignoring. Hovering an ignored row explains that it never switches. The built-in keyboard reserves the menu space but offers nothing. Changes save immediately; a persistence failure disables the picker and menu.
- Renaming uses a **Rename Keyboard** sheet with the product name as the placeholder; clearing the field restores the product name.
