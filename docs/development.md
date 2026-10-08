# Development

Keyameleon is a Swift 6 menu bar app built with AppKit, SwiftUI, and SwiftData. It targets macOS 26 and depends on one package, [Sparkle](https://sparkle-project.org), for updates.

## Prerequisites

- macOS 26 or later and Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [SwiftLint 0.65.1](https://github.com/realm/SwiftLint/releases/tag/0.65.1), the exact version pinned in `.swiftlint.yml` (see [SwiftLint](#swiftlint))
- An **Apple Development** signing certificate in your login keychain, for Debug builds

## Commands

Everything goes through `Scripts/run.sh`. Every command runs the [safety audit](#safety-audit) first.

| Command | What it does |
| --- | --- |
| `./Scripts/run.sh open` | Generate the project, build a Development-signed Debug app, and launch it |
| `./Scripts/run.sh test` | SwiftLint, then generate, then script tests, Swift Testing, and XCTest (the default command) |
| `./Scripts/run.sh generate` | Select your signing certificate and regenerate `Keyameleon.xcodeproj` |
| `./Scripts/run.sh build` | Generate and build the Debug app without launching it |
| `./Scripts/run.sh reset` | Quit every Keyameleon and erase its local state for a first-run test (see [Resetting local state](#resetting-local-state)) |
| `./Scripts/run.sh lint` | SwiftLint only |
| `./Scripts/run.sh audit` | Safety audit only |
| `./Scripts/run.sh release-tag vX.Y.Z` | Validate an Official Release tag name |

Build products land in `./build`.

## Xcode project

[`project.yml`](../project.yml) is the source of truth. XcodeGen generates `Keyameleon.xcodeproj` from it, so edit `project.yml` and run `./Scripts/run.sh generate`; never edit the generated project by hand.

`generate` also writes shared workspace settings that use modern build locations, and resets any per-user `UseTargetSettings` override. Legacy build locations stop Xcode from resolving Swift packages with `Packages are not supported when using legacy build locations`.

## Signing

Debug builds, including **Run** in Xcode, require an Apple Development certificate. macOS ties the Input Monitoring grant to the app's signature, so a stable signature keeps the permission across rebuilds; ad hoc signatures lose it.

- Run `./Scripts/run.sh generate` before your first Xcode Run and again after you change certificates. It writes the fingerprint of the first installed Apple Development certificate to the ignored `Config/Development.local.xcconfig`.
- Without a certificate, generation still succeeds (CI relies on this), but Debug builds fail rather than fall back to ad hoc signing.
- `run.sh test` signs the test host and bundles ad hoc, so tests need no certificate.
- No personal team or certificate identity is committed. Release signing is separate; see [Official Release](release/official-release.md).

## Debug and Release share one identity

Debug builds are the same app as the installed release: same bundle ID `dev.fedemas.keyameleon`, preferences, data and log folders, Keychain item, and [single-instance lock](adr/0002-one-keyameleon-instance-per-mac.md). Consequences:

- A Debug build reads and changes the settings and saved keyboards of an installed release.
- Only one of them runs at a time. `run.sh open` replaces this checkout's Debug app, but stops with an error if another Keyameleon is running and never quits it.
- Debug and CI builds lack the release `SUPublicEDKey`, so they never start Sparkle.
- The two builds have different signatures. After switching between them, check Input Monitoring in System Settings.

### Resetting local state

Every build you launch, in any worktree, DerivedData folder, mounted DMG or the Trash, stays registered with LaunchServices under the same bundle ID. When you change Input Monitoring, System Settings offers **Quit & Reopen**, which reopens Keyameleon by bundle ID, not by path. LaunchServices then picks one of the registered copies, which may not be the build you were testing.

`./Scripts/run.sh reset` returns the Mac to a never-installed state:

- Quits every running Keyameleon, including an installed release.
- Unregisters every registered copy from LaunchServices. The next copy you launch registers itself again, so Quit & Reopen finds it.
- Resets Keyameleon's privacy permissions (`tccutil reset All dev.fedemas.keyameleon`).
- Deletes its preferences, the saved keyboards in `~/Library/Application Support/Keyameleon`, and `~/Library/Logs/Keyameleon`.
- Deletes the pre-0.4.6 store at `~/Library/Application Support/default.store`, which launch would otherwise copy back. Other apps can use that path, so it is deleted only when it contains Keyameleon's keyboard table.

It keeps the Keychain integrity key, as a real uninstall would, and the Launch at Login item. Launch at Login can open a different copy than the one you test, so turn it off first.

Data from the retired `Keyameleon (Dev)` app stays in its own folders, preferences domain, and Keychain item. Keyameleon neither imports nor deletes it.

## Repository layout

```text
Sources/
  App/                         Entry point, application delegate, composition root, single-instance lock
  Features/
    ActivityTriggeredSwitching/  Keyboard discovery, event observation, Input Source selection, persistence
    Menu/                      Status item menu
    Onboarding/                Guided setup window
    Configuration/             Settings window (General, Keyboards)
    About/                     About pane and updates
    Shared/                    Models, theme, logging, and views used by several features
Tests/
  SwiftTesting/                Domain and model tests
  XCTest/                      AppKit shell tests
  Scripts/                     Python tests for CI and release scripts
Scripts/                       run.sh and the release tooling
Resources/                     Asset catalogs and menu icon
Config/                        Signing configuration
design/                        Pencil design file and references
```

Use the glossary in [`CONTEXT.md`](../CONTEXT.md) when naming domain concepts, and check [`docs/adr`](adr) and [`docs/choices.md`](choices.md) before changing established behavior.

## Safety audit

The audit greps `Sources`, `Tests`, and `project.yml` and fails the command when it finds:

- APIs that could inject, seize, or tap input (`CGEvent*`, `IOHIDPostEvent`, virtual HID devices, private `CGS*` symbols)
- Networking, analytics, or crash-upload APIs (`URLSession`, `Sentry`, `MetricKit`, and similar)
- `print`, `NSLog`, or `os_log` (use the `Log` pipeline instead)
- Key Content names (`KeyContent`, `rawReport`, `interpretedText`, `modifierState`) in the logging pipeline or at log call sites
- `CFArrayGetValueAtIndex`, which caused a use-after-free in optimized builds; bridge CF arrays to Swift arrays instead

Because the pattern is a plain grep, even naming a type such as `CGSize` in `Sources` trips the `CGS*` rule.

## SwiftLint

Local checks and CI run the same command:

```sh
swiftlint lint --strict --quiet --no-cache --config .swiftlint.yml
```

- It checks all of `Sources`, including preview fixtures. A different SwiftLint version, any warning, or any error fails the check. There is no violation baseline.
- Default rules stay on. Size limits are raised so existing models and screens pass without a refactor while further growth still fails: 1000 lines per file, 800 per type body, 120 per function body. Type and identifier names may reach 60 characters so they can use full domain terms.
- Cyclomatic complexity ignores `switch` cases, so exhaustive enum mappings do not count; branches and loops still do.
- CI and the Release workflow download the portable macOS archive and verify its SHA-256, `c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0`.

To upgrade SwiftLint, change the version in `.swiftlint.yml` and the download URL and checksum in both `.github/workflows/ci.yml` and `.github/workflows/release.yml` together, then recheck the sources.
