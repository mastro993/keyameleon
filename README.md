# Keyameleon

Keyameleon is a native Swift 6 macOS menu bar app for Multilingual Professionals.

## Build and test

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
./Scripts/run.sh test
```

Build and launch the shell with:

```sh
./Scripts/run.sh open
```

The app uses one AppKit process. It has no Dock icon. Its durable menu bar item opens or quits Keyameleon. Closing the window keeps the process running and allows the window to reopen from the menu.

## License

Keyameleon is free and open source under **`GPL-3.0-only`**. See [`LICENSE`](LICENSE) and
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Supported Release and security

The latest **Official Release** is the only **Supported Release**. Report
vulnerabilities privately — see [`SECURITY.md`](SECURITY.md).

## Official Release

Source-traceable, Developer ID signed, hardened-runtime, notarized, and stapled
artifacts publish through GitHub Releases when a Semantic Versioning tag
`vMAJOR.MINOR.PATCH` is pushed. Sparkle update metadata (`appcast.xml`) ships on
the same channel. Maintainer procedure and required secrets:
[`docs/release/official-release.md`](docs/release/official-release.md).
