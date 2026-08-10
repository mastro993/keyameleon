# Keyameleon

Keyameleon keeps the macOS Input Source aligned with the Physical Keyboard that produces input. It serves a Multilingual Professional who uses keyboards with different physical layouts.

## Language

**Physical Keyboard**:
An identifiable built-in or external keyboard that sends input to the Mac.
_Avoid_: Keyboard device, input device

**Physical Keyboard Identity**:
The stable and unique macOS facts that Keyameleon uses to recognize the same Physical Keyboard across disconnects and restarts. A Physical Keyboard without this identity cannot have a Keyboard Assignment.
_Avoid_: Keyboard identifier, device identity

**Manual Physical Keyboard Designation**:
A saved user decision that one stable and unique external identity group is a
Physical Keyboard. Keyameleon creates it only after the same identity leaves
and returns and the user confirms its Physical Keyboard Name.
_Avoid_: Keyboard override, trusted device

**Physical Keyboard Name**:
The user-visible name of a Physical Keyboard. It uses the macOS product name by default and can have a custom value. It does not identify the Physical Keyboard.
_Avoid_: Device name, keyboard label

**Physical Keyboard Event**:
An observable input-state change or repeat attributed to one Physical Keyboard. It can contain one or more simultaneous key transitions.
_Avoid_: Keyboard event, HID report

**Activation Activity**:
A Physical Keyboard Event that contains a key press or repeat and makes that Physical Keyboard active. Normal, modifier, function, media, lock, and exposed special-key presses count. A release-only event does not count.
_Avoid_: First activity, keyboard use

**Physical Keyboard State**:
The momentary set of keys and modifiers held on one Physical Keyboard. It does not include global lock state, such as Caps Lock.
_Avoid_: Keyboard state, key state

**Key Content**:
Information that identifies or can reconstruct input from one or more Physical Keyboard Events. It includes key transitions, modifiers, shortcuts, interpreted text, Physical Keyboard State, and their raw representations.
_Avoid_: Keystroke data, typed content

**Diagnostic Data**:
Information about Keyameleon operation that does not contain Key Content. It can include operational errors, operational state changes, observation order, relative timing, Input Source selection results, and temporary random tokens.
_Avoid_: Logs, telemetry

**Diagnostic Session**:
A user-started and time-limited period when Keyameleon records detailed Diagnostic Data for bug investigation.
_Avoid_: Debug mode, logging mode

**Diagnostic Bundle**:
A user-created export of Diagnostic Data for bug investigation. The user can save it or send it through the macOS share interface.
_Avoid_: Log archive, debug dump

**Unclean Exit**:
A launch condition where the previous Keyameleon process did not complete normal termination. Keyameleon keeps one local notice for the user to review or dismiss.
_Avoid_: Crash report, automatic crash notice

**Active Physical Keyboard**:
The Physical Keyboard that produced the last Activation Activity that Keyameleon observed. Keyameleon does not carry this condition across an app restart; after restart, there is no Active Physical Keyboard until new Activation Activity.
_Avoid_: Current keyboard, last keyboard

**Input Source**:
A macOS text-input configuration, such as a language-specific keyboard layout, that interprets key input.
_Avoid_: Source input, keyboard language

**Keyboard Assignment**:
The saved relation between one Physical Keyboard and its wanted Input Source.
_Avoid_: Mapping, binding

**Unavailable Keyboard Assignment**:
A Keyboard Assignment whose Input Source is not available. Keyameleon keeps the assignment and does not select a substitute Input Source.
_Avoid_: Broken assignment, missing assignment

**Switching Status**:
The current global condition of Activity-Triggered Switching: Ready, Permission Required, Paused, or Temporarily Unavailable. It is separate from the condition of one Physical Keyboard or Keyboard Assignment.
_Avoid_: App status, operational status

**Activity-Triggered Switching**:
The product behavior that requests and verifies a Keyboard Assignment after Keyameleon observes Activation Activity. It does not delay or change the original Physical Keyboard Event. That event and later events that macOS processes before verification can use the previous Input Source.
_Avoid_: First-activity guarantee, next-key guarantee, best-effort switching

**First-Key Guarantee**:
The product promise that the first key pressed after the user changes Physical Keyboard uses that keyboard's assigned Input Source.
_Avoid_: Next-key switching, best-effort switching

**Multilingual Professional**:
The primary V1 user: one person who uses the same Mac with keyboards that have different physical layouts.
_Avoid_: Power user, general Mac user

**Official Release**:
A version of Keyameleon that the person with release authority publishes for users. It has a source version that users can inspect.
_Avoid_: Official build, production build

**Supported Release**:
The latest Official Release. It receives maintenance for the supported macOS versions.
_Avoid_: Supported build, current version
