<img width="1920" height="540" alt="Keyameleon banner" src="https://github.com/user-attachments/assets/090bad21-77f1-4c04-ae1f-5e18a51928c3" />

<div align="center">
  <h1>Keyameleon</h1>
  <p><strong>Every keyboard speaks its own language.</strong></p>
  <p>
    <a href="https://github.com/mastro993/Keyameleon/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/mastro993/Keyameleon"></a>
    <a href="https://github.com/mastro993/Keyameleon/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/mastro993/Keyameleon/actions/workflows/ci.yml/badge.svg"></a>
    <img alt="macOS 26 or later" src="https://img.shields.io/badge/macOS-26%2B-blue">
    <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/mastro993/Keyameleon"></a>
  </p>
  <p>
    <a href="#install">Install</a> ·
    <a href="#how-it-works">How it works</a> ·
    <a href="#privacy">Privacy</a> ·
    <a href="#build-from-source">Build from source</a> ·
    <a href="https://keyameleon.app/">Website</a>
  </p>
</div>

Keyameleon is a macOS menu bar app that switches the keyboard layout to match the keyboard you are typing on. If you use one Mac with keyboards that have different physical layouts, such as a US laptop keyboard and an Italian external keyboard, you no longer switch layouts by hand.

<!-- Add assets/screenshot.png here: the menu bar icon and the open menu, with two or more assigned keyboards and one active. -->

## Features

- **One layout per keyboard.** Assign an Input Source to each Physical Keyboard once; Keyameleon remembers it across disconnects and restarts.
- **Automatic switching.** Press a key and Keyameleon selects that keyboard's Input Source, then verifies the change.
- **Menu bar only.** No Dock icon. The menu shows your assigned keyboards, which one is active, and any problem that needs attention.
- **Guided setup.** One walkthrough grants Input Monitoring, assigns layouts, and confirms everything is ready.
- **Rename and ignore devices.** Give keyboards your own names, and ignore devices (such as a mouse with shortcut keys) that macOS reports as keyboards.
- **Pause and resume** with <kbd>⌘</kbd><kbd>P</kbd> from the menu.
- **Launch at login**, if you want it.
- **Updates you approve.** Keyameleon checks for updates at most once a day and never installs one without your approval.

## Requirements

- macOS 26 or later, on Apple silicon or Intel.
- The **Input Monitoring** permission. Keyameleon uses it to see which keyboard you pressed a key on.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask mastro993/tap/keyameleon
```

Or download `Keyameleon-<version>.dmg` from the [latest release](https://github.com/mastro993/Keyameleon/releases/latest), open it, and drag Keyameleon to Applications.

Both install the same signed and notarized app, and Keyameleon updates itself either way.

### First launch

Guided setup opens on first launch:

1. **Permissions.** Choose **Allow Input Monitoring**, then turn Keyameleon on in System Settings. If macOS asks, choose **Quit & Reopen**. Setup continues by itself once access is granted.
2. **Keyboards.** Pick an Input Source for each keyboard. You can skip this and assign layouts later in Settings.
3. **Ready.** Finish, and Keyameleon stays in the menu bar.

If you close the setup window early, choose **Continue Guided Setup** from the menu bar to pick up where you left off. Closing a window never quits the app; use **Quit Keyameleon** in the menu.

## How it works

Keyameleon watches keyboard activity through Apple's CoreHID framework in listen-only mode. When you press a key, it identifies the keyboard, looks up that keyboard's assignment, and asks macOS to select the matching Input Source. It then reads the Input Source back to confirm the switch.

Things worth knowing:

- **The first key can use the old layout.** Keyameleon never delays or changes your input, so the key press that triggers a switch, and any keys macOS handles before the switch completes, use the previous layout.
- **Each keyboard needs a stable identity.** Keyameleon recognizes an external keyboard by its hardware identity. A keyboard that macOS cannot identify reliably is listed but cannot receive an assignment.
- **Missing layouts are never replaced.** If an assigned Input Source is removed from macOS, Keyameleon keeps the assignment, shows a warning, and does not pick a substitute.
- **Only one copy runs per Mac.** A second copy, even of another version, exits silently on launch.

## Privacy

Keyameleon is monitor-only. It cannot inject or alter keystrokes: CoreHID gives it read access, and layout changes go through the macOS text input system.

What you type never leaves the classification step: no keystrokes, modifiers, or shortcuts reach saved data, log files, or the network. There are no analytics and no automatic uploads. The only network requests are update checks and the updates you approve.

Keyameleon stores data locally:

| What | Where |
| --- | --- |
| Keyboard names and assignments | `~/Library/Application Support/Keyameleon/` |
| Setup progress, ignored devices, pause state | Preferences domain `dev.fedemas.keyameleon` |
| Integrity key that protects saved keyboard designations | Keychain item `dev.fedemas.keyameleon.installation-integrity` |
| Operational logs (no typed content) | `~/Library/Logs/Keyameleon/` |

**Settings → About** opens the data and log folders in Finder.

## Troubleshooting

- **Keyameleon does not switch layouts.** Open the menu. A notice explains what is wrong (missing permission, paused, unavailable layout) and offers the fix.
- **Input Monitoring is on, but Keyameleon says it is off.** Choose **Restart Keyameleon** in the menu. This often happens after reinstalling. If it is still off after the restart, Keyameleon clears its old entry and asks again, so you only have to turn it back on.
- **Something else went wrong.** Attach the relevant lines from `~/Library/Logs/Keyameleon/keyameleon.log` to a [bug report](https://github.com/mastro993/Keyameleon/issues/new/choose).

## Uninstall

Quit Keyameleon from the menu, then delete the app, or run `brew uninstall --cask keyameleon`. To remove its data as well, delete the folders and Keychain item listed under [Privacy](#privacy) and run `defaults delete dev.fedemas.keyameleon`.

## Build from source

You need macOS 26, Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and an Apple Development certificate.

```sh
brew install xcodegen
./Scripts/run.sh open   # generate the project, build a Debug app, and launch it
./Scripts/run.sh test   # safety audit, SwiftLint, and the full test suite
```

[`docs/development.md`](docs/development.md) covers signing, project generation, and the repository layout.

## Documentation

| Document | Contents |
| --- | --- |
| [`CONTEXT.md`](CONTEXT.md) | Product vocabulary: Physical Keyboard, Input Source, Keyboard Assignment, and more |
| [`docs/development.md`](docs/development.md) | Building, signing, and repository layout |
| [`docs/testing.md`](docs/testing.md) | Automated tests, CI, and manual verification checklists |
| [`docs/choices.md`](docs/choices.md) | Current design decisions, by feature |
| [`docs/adr/`](docs/adr) | Architecture decision records |
| [`docs/release/official-release.md`](docs/release/official-release.md) | How Official Releases are signed, published, and verified |

## Contributing

Bug reports, feature ideas, and pull requests are welcome. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first. Report security issues privately as described in [`SECURITY.md`](SECURITY.md).

## License

Keyameleon is released under the [MIT License](LICENSE). It uses [Sparkle](https://sparkle-project.org) for updates; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
