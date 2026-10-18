# Activity-Triggered Switching

`ActivityTriggeredSwitching` is the single switching module. It selects the **Wanted Input Source** after **Activation Activity** or an **App Activation** ([ADR 0007](../adr/0007-app-assignments-override-keyboard-assignments.md)). It exposes one immutable outcome and ten operations: start, stop, request permission, check again, pause, resume, retry now, set the External Change Response, switch back now, and select an Input Source for [automation](automation.md), which also lists the Input Sources it may select. Its permission actions depend on the Input Monitoring decision: unknown offers Request Permission; denied offers Open System Settings and Relaunch. Discovery, Input Source selection, and record storage stay behind their own modules.

## Switching

- Only **Activation Activity** (a key press or repeat) makes a keyboard active; release-only events do not. The **Active Physical Keyboard** is never persisted across restarts.
- The Wanted Input Source is the **Frontmost App**'s **App Assignment** if it has one, otherwise the Active Physical Keyboard's Keyboard Assignment, otherwise none. See [App Assignments](#app-assignments).
- Keyameleon requests the exact wanted Input Source and reads it back to verify. It does not delay or change the triggering event, so that event and anything macOS handles before verification can use the previous Input Source.
- Requests are serialized in observation order and tagged with a generation, so stale readbacks from rapid typing across keyboards are discarded.
- A request is skipped when the Wanted Input Source is already verified and current. Two keyboards assigned to the same Input Source therefore switch the active keyboard without selecting again.
- If the Input Source changes outside Keyameleon, Keyameleon records it but does not fight it. What happens next depends on the External Change Response (see [External Input Source Changes](#external-input-source-changes)).
- Before selecting, including on Retry Now, Keyameleon reads the keyboard's saved name. If that read fails, it selects nothing.

## App Assignments

An **App Assignment** gives one app, recognized by its bundle identifier, an Input Source on every Physical Keyboard. It wins over the Keyboard Assignment while its app is the Frontmost App ([ADR 0007](../adr/0007-app-assignments-override-keyboard-assignments.md)). For example, an external keyboard on Italian still types U.S. in Terminal.

- An **App Activation** (macOS making another app active) triggers switching, like Activation Activity. Leaving an assigned app selects the Active Physical Keyboard's Keyboard Assignment right away, or nothing when there is none.
- An App Assignment applies even with no Active Physical Keyboard, such as after a fresh launch, and with no Keyboard Assignments at all.
- Keyameleon itself becoming active, for example its Settings window, is not an App Activation: the Frontmost App stays the previous app, so editing an App Assignment never switches the Input Source under you. Edits apply from the next trigger.
- An **Unavailable App Assignment** is kept and selects nothing while its app is frontmost; there is no fallback to the Keyboard Assignment. A warning shows, and the menu's app pill carries the warning triangle.
- An uninstalled app keeps its App Assignment and shows `Not installed`. Nothing removes it automatically.
- Pause, any Switching Status other than Ready, and Guided setup block App Assignments as they block Keyboard Assignments.
- macOS "Automatically switch to a document's input source" also switches on app activation; Keyameleon sees those changes as External Input Source Changes. The Apps pane footer suggests turning it off.
- App Assignments live in the SwiftData store (schema version 2, a lightweight migration that only adds them). `ActivityTriggeredSwitching` reads them once on start and after each saved change, never per key press. The frontmost app comes from `NSWorkspace.didActivateApplicationNotification`, which needs no permission.
- Website Assignments, above App Assignments in the same chain, are planned in [#188](https://github.com/mastro993/keyameleon/issues/188).

## External Input Source Changes

An **External Input Source Change** is any change of the current Input Source that Activity-Triggered Switching did not make: a keyboard shortcut, the menu bar, the Globe key, Keyameleon's own [Shortcuts actions and URL scheme](automation.md#selecting-an-input-source), macOS per-document switching, an input method toggling modes (Japanese Kana/Eisu, Caps Lock switching to and from ABC), or another app. Keyameleon cannot tell them apart and treats them all the same. Activity-Triggered Switching's own selections never count: each one updates the observed Input Source before its change notification arrives.

The global **External Change Response** (General settings) decides what happens next:

- **Switch Back** (default, `Switch back`): no Input Source Hold; the next Activation Activity applies the Keyboard Assignment. Updating users see no behavior change.
- **Hold Until Match** (`Keep until matching keyboard`): an **Input Source Hold** starts and ends on Activation Activity after which the Wanted Input Source equals the current Input Source, checked at each key press. An unassigned keyboard never ends it, and while an assigned app is frontmost only its App Assignment matches.
- **Hold Until Keyboard Change** (`Keep until another keyboard`): a hold starts, tied to the Active Physical Keyboard, and ends on Activation Activity from a different Physical Keyboard. An unassigned keyboard ends it without selecting anything; typing on the original keyboard then switches back. With no Active Physical Keyboard at the time of the change (fresh launch, before any typing), the first keyboard typed on becomes the holding keyboard. The holding keyboard disconnecting ends the hold. Ignored devices produce no Activation Activity, so they never end a hold.

Further rules:

- No hold starts when the new Input Source already equals the Wanted Input Source, or when Switching Status is not Ready (Paused, Permission Required, during Guided setup). The change is still recorded, so the outcome names the current Input Source.
- Another External Input Source Change during a hold does not restart it.
- Any hold ends on an App Activation, app restart, Pause then Resume, changing the External Change Response, editing or removing the holding keyboard's Keyboard Assignment (for Hold Until Match, the Active Physical Keyboard's) or the Frontmost App's App Assignment, or **Switch Back Now** in the menu, which also applies the Wanted Input Source. Sleep and wake keep the hold.
- The hold lives in memory only and is never saved. The response is saved in UserDefaults under `keyameleon.activityTriggeredSwitching.externalChangeResponse`.
- `InputSourceHoldPolicy` owns every start and end rule that depends on keyboards and Input Sources, as pure functions with unit tests.

There is no **switch back right away** option that reverts the change as soon as it is noticed. It would fight macOS per-document switching, input methods, and other switcher apps, could loop against them, and would reverse the "no fight" choice from [#6](https://github.com/mastro993/keyameleon/issues/6). Remembering the change as the keyboard's new Keyboard Assignment is left to an explicit action, and a per-keyboard response is left out for simplicity.

## Failures and recovery

- **Selection failure:** the previous Input Source is restored when the readback does not match. One warning tracks the current Wanted Input Source, with **Retry Now**. There is no timed retry loop.
- **Unavailable Keyboard Assignment:** when an assigned Input Source disappears from macOS, the assignment is kept, nothing is selected in its place, and a warning shows. It clears when the exact Input Source returns.
- **CoreHID streams** resubscribe after any exit other than cancellation, with a one-second delay so a failing Mac cannot loop tightly.

## Switching Status

**Switching Status** resolves in priority order: Permission Required, then Temporarily Unavailable, then Paused, then Ready.

- **Temporarily Unavailable** covers sleep, an inactive login session, Secure Input, and unavailable protected data. Discovery stops while asleep or locked.
- **Pause** is persisted (`keyameleon.activityTriggeredSwitching.paused` in UserDefaults). It stops observation and Input Source requests but keeps discovery running so keyboards can still be managed. Resume clears the pause, rechecks permission, and starts observation only if Ready.
- The status item icon uses a distinct SF Symbol shape per state, not just a color. Per-keyboard warnings show on the icon only when the status is Ready.
