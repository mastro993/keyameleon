<img width="1920" height="540" alt="banner" src="https://github.com/user-attachments/assets/090bad21-77f1-4c04-ae1f-5e18a51928c3" />

<div align="center">
   <h1>Keyameleon</h1>
   <p>Every keyboard speaks its own language.</p>
</div>

Keyameleon is a macOS menu bar app that keeps the Input Source aligned with the Physical Keyboard you are typing on. Set it up if one Mac has several Physical Keyboards with different physical layouts and you keep switching layouts by hand.

<!-- Add assets/screenshot.png here: the menu bar icon and the open panel, with the Keyboards list visible. -->

## Features

- **Keyboard Assignments**: one saved Input Source per Physical Keyboard
- **Activity-Triggered Switching**: after you press a key, Keyameleon selects and verifies that keyboard's Input Source
- **Menu bar panel**: every keyboard with its assignment, the Active Physical Keyboard, and Switching Status, with no Dock icon
- **Guided setup**: Input Monitoring, Keyboard Assignments, and a Ready handoff in one walkthrough
- **Pause and resume**: stops observation and Input Source requests until you resume
- **Launch at Login**: optional
- **User-approved updates**: Keyameleon checks for updates once a day at most and installs one only when you approve it
- **Local logging**: writes `verbose`, `debug`, `warning`, and `error` lines to log files under `~/Library/Logs/Keyameleon`, and the About page opens that folder

Keyameleon is monitor-only: it observes Physical Keyboard Events through CoreHID, which cannot change or inject input, and it selects layouts through the macOS text input system. Key Content stays inside classification, so it never reaches saved data, log files, or the network. There is no analytics and no automatic upload.

## Requirements

- macOS 26 or later.
- Input Monitoring permission, which Activity-Triggered Switching uses to observe Activation Activity.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask mastro993/tap/keyameleon
```

Or download the DMG from the [latest release](https://github.com/mastro993/Keyameleon/releases/latest), open it, and drag Keyameleon into Applications. Both install the same app, and Keyameleon updates itself. `brew upgrade` also upgrades the cask when the installed app's version is older than the tap's. To run your own build instead, see [Development setup](#development-setup).

The app lives in the menu bar: closing its window does not quit it, and you quit from the menu bar. On first launch, Guided setup asks for Input Monitoring, lets you assign Input Sources to Physical Keyboards, and ends on a Ready screen. You can finish without assignments and add them later in Settings. If Input Monitoring is already granted, setup advances automatically. Closing the setup window saves your place; the menu bar keeps running.

## Development setup

Keyameleon is a Swift 6 AppKit and SwiftUI menu bar app. [`project.yml`](project.yml) is the source of truth for the Xcode project, and XcodeGen generates `Keyameleon.xcodeproj` from it. Edit `project.yml`, not the generated project.

You need macOS 26 or later, Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and an Apple Development signing identity.

```sh
brew install xcodegen
./Scripts/run.sh open      # generate, build a Development-signed Debug app, launch it
./Scripts/run.sh test      # safety audit, then Swift Testing and XCTest bundles
./Scripts/run.sh generate  # select your local certificate and regenerate the Xcode project
```

Xcode Run, `run.sh build`, and `run.sh open` require an Apple Development identity for Debug builds. A stable signing identity lets macOS recognize the app across rebuilds and retain its Input Monitoring grant. Before the first Xcode Run, use `./Scripts/run.sh generate`. It selects the first installed Apple Development certificate and writes its fingerprint to the ignored `Config/Development.local.xcconfig`. Run it again after changing certificates. No personal team or certificate identity is committed. Generation still works without a certificate for CI; normal Debug builds require one. Official Release signing is unchanged. `run.sh test` explicitly uses ad hoc signing so hosted tests also run on CI without a certificate. Build products from the script land in `./build`.

Tests live in `Tests/SwiftTesting` for domain and model seams, and in `Tests/XCTest` for AppKit shell contracts. [`CONTEXT.md`](CONTEXT.md) holds the product vocabulary, and [`docs/adr`](docs/adr) records the decisions behind the switching rules and the single-instance behavior.

## Contributing

Changes land on `main` through pull requests only, and [CI](.github/workflows/ci.yml) runs the safety audit and the test bundles. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before you open one. Report security issues privately, as described in [`SECURITY.md`](SECURITY.md).

## License

[MIT](LICENSE). Third-party notices: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
