# Automation

Shortcuts actions and a URL scheme let launchers and scripts control Keyameleon without the menu ([#196](https://github.com/mastro993/keyameleon/issues/196)). Both run the same `AutomationCommand` in `Sources/Features/Automation`, so they behave the same.

## Shortcuts actions

App Intents in the app target, listed under Keyameleon in the Shortcuts app:

- **Pause Switching** and **Resume Switching** do what the menu command does. Running one when switching is already in that state changes nothing.
- **Pause or Resume Switching** pauses when switching runs and resumes when it is paused.
- **Select Input Source** offers the same Input Sources as the Keyboard Assignment pickers: enabled, selectable keyboard layouts.
- **Get Active Keyboard and Input Source** returns the Active Physical Keyboard's name and the current Input Source's name. Both are empty before any Activation Activity after launch, as in the menu.

There are no App Shortcuts phrases and no Siri suggestions; people build their own shortcuts. Shortcuts launches Keyameleon in the background when it is not running, and the action runs once launch has registered the switching module with `AppDependencyManager`.

## URL scheme

The Release build registers `keyameleon://`; the Debug build registers `keyameleon-dev://`, so a URL always reaches the installed release ([ADR 0008](../adr/0008-separate-debug-identity.md)). The scheme comes from the `KEYAMELEON_URL_SCHEME` build setting.

| URL | Action |
| --- | --- |
| `keyameleon://pause` | Pause Switching |
| `keyameleon://resume` | Resume Switching |
| `keyameleon://toggle-pause` | Pause or Resume Switching |
| `keyameleon://select-input-source?id=com.apple.keylayout.US` | Select Input Source by identifier |
| `keyameleon://select-input-source?name=U.S.` | Select Input Source by its exact macOS name |

Actions are case-insensitive; `id` wins over `name`. A URL cannot return a value, so there is no URL for Get Active Keyboard and Input Source. An unknown action or a failed selection writes one `warning` line to the Log File and shows nothing, because Keyameleon has no notifications.

## Selecting an Input Source

A selection from Shortcuts or a URL is an **External Input Source Change**, exactly like one from the macOS menu bar or a keyboard shortcut. The **External Change Response** decides what happens next: with Switch Back, the next Activation Activity on an assigned keyboard selects its Keyboard Assignment again; with either hold, an **Input Source Hold** starts by the usual rules. While paused, nothing switches back.

Rejected: a hold that always starts after an automation selection. It would add a second set of hold rules beside the External Change Response. Chaining Pause Switching and Select Input Source in a shortcut keeps an Input Source with no new rule.

Selection uses the Text Input Sources API and verifies the readback, like Activity-Triggered Switching. An Input Source that is not available, or one macOS does not keep, fails the Shortcuts action with a localized error.

## Not in this repository

A Raycast extension built on the URL scheme belongs in the Raycast extensions repository, and the website integrations section belongs to the website.
