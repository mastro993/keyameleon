# Keyameleon

Every keyboard speaks its own language.

Keyameleon is a native macOS menu bar app. It keeps the Input Source aligned
with the Physical Keyboard that produces input. Use it when you have more than
one Physical Keyboard, and those keyboards have different physical layouts.

![Keyameleon menu bar panel with assigned Physical Keyboards and Switching Status Ready](assets/screenshot.png)

Add `assets/screenshot.png`: the menu-bar icon and the open panel. Heading
**Keyboards**. At least two assigned pills, each showing a Physical Keyboard
Name and its assigned Input Source. One pill marked **Active**. Switching
Status **Ready**. No Key Content. No Settings window.

## Installation

**Official Release:** download the latest `Keyameleon-<version>.zip` from the
[releases page](https://github.com/mastro993/Keyameleon/releases/latest), open
it, and drag Keyameleon into Applications.

The app checks for updates at most once a day through signed, notarized Sparkle
updates. You approve every install. Keyameleon does not download or install an
update on its own.

**From source:** see [Building](#building).

Requires macOS 26 or later.

## Getting started

1. Open Keyameleon. It lives in the menu bar and has no Dock icon.
2. Grant Input Monitoring when Guided setup asks. Activity-Triggered Switching
   needs it to observe Activation Activity from each Physical Keyboard.
3. Give each Physical Keyboard a Keyboard Assignment (its Input Source).
4. Type on a keyboard. After Activation Activity, Keyameleon selects and
   verifies that keyboard's Keyboard Assignment.

Keyameleon does not delay or change the original Physical Keyboard Event.
Events that macOS processes before Input Source verification finishes can use
the previous Input Source.

Closing the window does not quit. Reopen or quit from the menu bar.

## Features

- **Keyboard Assignments.** One saved Input Source per Physical Keyboard.
- **Menu bar panel.** Assigned keyboards, an Active mark, Switching Status, and
  daily actions.
- **Activity-Triggered Switching.** After Activation Activity, select and
  verify the exact Keyboard Assignment.
- **Guided setup.** Input Monitoring, Physical Keyboard Names, assignments, and
  optional operational notifications.
- **Pause and resume.** Pause stops observation and Input Source requests.
  Discovery for management continues.
- **Launch at Login.** Optional.
- **User-approved updates.** Sparkle checks at most every 24 hours. No
  automatic install. No system profiling.
- **Built-in keyboard.** All built-in keyboard services are one Physical
  Keyboard.
- **Manual Physical Keyboard Designation.** Confirm an ambiguous external
  identity after it leaves and returns.
- **Unavailable Keyboard Assignment.** The assignment stays. Keyameleon does
  not pick a substitute Input Source. Retry Now recovers a selection failure.
- **One instance per Mac.** A later launch exits. The running process is
  unchanged.
- **Diagnostics.** Allowlisted Diagnostic Data, a time-limited Diagnostic
  Session, and a Diagnostic Bundle you can review, save, or share. No Key
  Content.

## Privacy

Keyameleon is monitor-only. It never injects or changes Physical Keyboard
Events.

Key Content stays inside observation and classification. It does not enter
saved data, Diagnostic Data, logs, network output, or crash state.

There is no analytics and no automatic diagnostic upload. Diagnostic Data is
an allowlisted operational record. You start a Diagnostic Session, and you
export a Diagnostic Bundle.

Activity-Triggered Switching needs Input Monitoring. Keyameleon observes
Activation Activity so it can select the assigned Input Source. It does not
use that permission to record what you type.

## Requirements

- macOS 26 or later
- Input Monitoring permission for Activity-Triggered Switching

## Architecture

One AppKit process owns the `NSStatusItem` and a transient SwiftUI popover.
Swift 6 with complete concurrency checking. SwiftData stores Physical Keyboard
records; Diagnostic Data uses a separate store. CoreHID is listen-only (no
seize, no event injection). Input Source selection goes through TIS.

See [`CONTEXT.md`](CONTEXT.md) for the product glossary.

## Building

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then:

```sh
./Scripts/run.sh test   # generate, test, safety audit
./Scripts/run.sh open   # generate, Development-sign, launch
```

`./Scripts/run.sh open` needs an Apple Development identity so macOS can keep
Input Monitoring across launches.

## Releasing

The latest Official Release is the only Supported Release. Artifacts are
source-traceable, Developer ID signed, hardened-runtime, notarized, and
stapled. Sparkle `appcast.xml` ships on the same GitHub Releases channel.

Push an annotated Semantic Versioning tag on a reviewed, green `main`:

```sh
git tag -a v1.2.3 -m "Keyameleon 1.2.3"
git push origin v1.2.3
```

Only `vMAJOR.MINOR.PATCH` starts the Official Release workflow. Pre-release
tags (`v1.2.3-beta.1`) and bare versions (`1.2.3`) do not.

The `produce` job targets the `official-release` GitHub Environment. After
approval (when the host plan enforces reviewers), CI builds, signs,
notarizes, staples, writes `appcast.xml` and `release-evidence.json`, and
publishes:

- `Keyameleon-<version>.zip`
- `Keyameleon-source-<version>.tar.gz`
- `appcast.xml`
- `release-evidence.json`

Full procedure, host protections, and local production:
[`docs/release/official-release.md`](docs/release/official-release.md).

### Release secrets (never commit)

| Secret | What it is |
| --- | --- |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64` | Developer ID Application certificate (p12, base64) |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD` | p12 password |
| `APPLE_API_KEY_ID` | App Store Connect API key id for notarytool |
| `APPLE_API_ISSUER_ID` | API issuer id |
| `APPLE_API_KEY_P8_BASE64` | API private key `.p8` contents (base64) |
| `APPLE_TEAM_ID` | Developer team id |
| `SPARKLE_PRIVATE_ED_KEY` | Sparkle EdDSA private key (`generate_appcast` / `sign_update`) |
| `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA public key, baked in as `SUPublicEDKey` |

Optional variable: `CODESIGN_IDENTITY` (defaults to `Developer ID Application`).

Keep certificate and Sparkle recovery material offline or in the maintainer
secret store. Do not commit `*.p12`, `*.p8`, Sparkle private keys, or
`secrets/`.

## Contributing

Issues are welcome. Changes land on `main` only through pull requests. Read
[`CONTRIBUTING.md`](CONTRIBUTING.md) before opening one.

Report security issues privately. See [`SECURITY.md`](SECURITY.md).

## License

[GPL-3.0-only](LICENSE). Third-party notices:
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
