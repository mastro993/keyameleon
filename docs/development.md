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
| `./Scripts/run.sh reset` | Quit the Debug app and erase its local state for a first-run test; `reset --release` does the same for the installed release (see [Resetting local state](#resetting-local-state)) |
| `./Scripts/run.sh lint` | SwiftLint only |
| `./Scripts/run.sh audit` | Safety audit only |
| `./Scripts/run.sh release-tag vX.Y.Z` | Validate an Official Release tag name |

Build products land in `./build`, and test builds in `./build/test` (see [Signing](#signing)).

## Xcode project

[`project.yml`](../project.yml) is the source of truth. XcodeGen generates `Keyameleon.xcodeproj` from it, so edit `project.yml` and run `./Scripts/run.sh generate`; never edit the generated project by hand.

`generate` also writes shared workspace settings that use modern build locations, and resets any per-user `UseTargetSettings` override. Legacy build locations stop Xcode from resolving Swift packages with `Packages are not supported when using legacy build locations`.

## Signing

Debug builds, including **Run** in Xcode, require an Apple Development certificate. macOS ties the Input Monitoring grant to the app's signature, so a stable signature keeps the permission across rebuilds; ad hoc signatures lose it.

- Run `./Scripts/run.sh generate` before your first Xcode Run and again after you change certificates. It writes the fingerprint of the first installed Apple Development certificate to the ignored `Config/Development.local.xcconfig`.
- Without a certificate, generation still succeeds (CI relies on this), but Debug builds fail rather than fall back to ad hoc signing.
- `run.sh test` signs the test host and bundles ad hoc, so tests need no certificate. It builds them in `./build/test`, so the ad hoc app never replaces the signed Debug app and its grant, and unregisters the test host from LaunchServices afterwards so Quit & Reopen cannot open it.
- No personal team or certificate identity is committed. Release signing is separate; see [Official Release](release/official-release.md).

## Debug has its own identity

Debug builds, including Xcode Run, `run.sh open`, and the hosted test app, are a separate app to macOS ([ADR 0008](adr/0008-separate-debug-identity.md)):

| | Release, including Official Releases | Debug |
| --- | --- | --- |
| Bundle ID and preferences domain | `dev.fedemas.keyameleon` | `dev.fedemas.keyameleon.debug` |
| Name in System Settings, Finder, and Keyameleon's own windows | Keyameleon | Keyameleon (Dev) |
| Bundle | `Keyameleon.app` | `Keyameleon (Dev).app` |
| Saved keyboards | `~/Library/Application Support/Keyameleon` | `~/Library/Application Support/Keyameleon Dev` |
| Log File | `~/Library/Logs/Keyameleon` | `~/Library/Logs/Keyameleon Dev` |
| Input Monitoring | its own row | its own row |

- A Debug build never reads or changes the installed release's settings, saved keyboards, logs, or Input Monitoring grant. Restart Keyameleon's stale-row reset (`tccutil reset ListenEvent <bundle ID>`) clears only the running build's own row.
- The Debug store starts empty. It never imports the pre-0.4.6 store at `~/Library/Application Support/default.store`: even a Keyameleon store there holds an old release's data. Only the release imports it, and only when it is Keyameleon's.
- Folder names follow the bundle ID, not the display name, so renaming or localizing the app never moves data. The Debug folders are `Keyameleon Dev`, not `Keyameleon (Dev)`, which holds the retired app's data.
- Debug's `PRODUCT_NAME` is `Keyameleon (Dev)`, because System Settings and Finder name an app after its bundle file. `PRODUCT_MODULE_NAME` and `EXECUTABLE_NAME` stay `Keyameleon` in both, so `@testable import Keyameleon` and the executable inside the bundle are unchanged.
- Both share the [single-instance lock](adr/0002-one-keyameleon-instance-per-mac.md), so only one Keyameleon runs at a time and two never fight over the Input Source. `run.sh open` replaces this checkout's Debug app, but stops with an error if any other Keyameleon, including the installed release, is running, and never quits it.
- The Keychain item keeps the same service name. Each build uses the integrity key only to sign designations in its own store, so whether the two builds see the same item changes nothing.
- Debug and CI builds lack the release `SUPublicEDKey`, so they never start Sparkle.
- Code that recognizes Keyameleon itself by bundle ID must accept both IDs.

Data from the retired `Keyameleon (Dev)` app (`dev.fedemas.keyameleon.development`) stays in its own folders, preferences domain, and Keychain item. Keyameleon neither imports nor deletes it.

### Resetting local state

Every build you launch, in any worktree, DerivedData folder, mounted DMG or the Trash, stays registered with LaunchServices under its bundle ID. When you change Input Monitoring, System Settings offers **Quit & Reopen**, which reopens Keyameleon by bundle ID, not by path. LaunchServices then picks one of the registered copies with that ID, which may not be the build you were testing.

Debug apps built before Debug got its own identity, or from a branch without it, still carry the release ID and stay registered under it, so Quit & Reopen for the installed release could open one. Rebuild them, or delete their `build` folders and unregister each copy with `lsregister -u <path to Keyameleon.app>`, using the `LSREGISTER` path from `Scripts/run.sh`.

`./Scripts/run.sh reset` returns the Mac to a never-installed state for the Debug identity. It never touches the installed release:

- Quits every running Debug copy.
- Resets the Debug privacy permissions (`tccutil reset All dev.fedemas.keyameleon.debug`). `tccutil` finds the app through LaunchServices, so this runs before any copy is unregistered. If no copy is registered, it warns and the reset continues.
- Removes the Launch at Login item of every registered Debug copy. Debug builds made before this change are named Keyameleon too, so items are matched by path. If System Events can't remove them, the reset warns and continues; turn it off in System Settings > General > Login Items.
- Deletes the Debug preferences, including Guided setup progress, `~/Library/Application Support/Keyameleon Dev`, `~/Library/Logs/Keyameleon Dev`, and its caches.
- Unregisters every registered Debug copy from LaunchServices, last, and fails if one can't be unregistered. The next copy you launch registers itself again, so Quit & Reopen finds it.

`./Scripts/run.sh reset --release` does the same for the release identity, `dev.fedemas.keyameleon`: it quits an installed release and erases its permissions, Launch at Login item, preferences, saved keyboards in `~/Library/Application Support/Keyameleon`, and `~/Library/Logs/Keyameleon`. Use it only on a Mac whose Keyameleon data you can lose. It also deletes the pre-0.4.6 store at `~/Library/Application Support/default.store`, which a release launch would otherwise copy back. Other apps can use that path, so it is deleted only when it holds Keyameleon's keyboard table and no tables other than Keyameleon's and Core Data's own. Launch imports only such a store, so any other file, including one that also holds Keyameleon's tables, is kept. Debug state stays.

Both keep the Keychain integrity key. The key lives in the data-protection keychain, which the `security` CLI can't reach, and it only signs data the reset deletes, so the next launch still behaves as a first run.

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
Resources/                     Asset catalogs, menu icon, and string catalogs (Localization/)
Config/                        Signing configuration
design/                        Pencil design file and references
```

Use the glossary in [`CONTEXT.md`](../CONTEXT.md) when naming domain concepts, and check [`docs/adr`](adr) and [`docs/choices.md`](choices.md) before changing established behavior.

## Localization

User-visible strings live in [`Resources/Localization/Localizable.xcstrings`](../Resources/Localization/Localizable.xcstrings); `Info.plist` strings live in `InfoPlist.xcstrings` beside it. See [Localization](choices.md#localization) for the languages and rules.

To add or change a string:

1. Add a camelCase key with `extractionState` set to `manual`, a comment that tells translators where the string appears, and a translation for every language. Plurals use plural variations; multi-argument strings use positional specifiers (`%1$@`, `%2$@`).
2. Build. Xcode generates a symbol for the key, so SwiftUI code uses `Text(.key)` or `Button(.key) { … }`, and code that needs a `String` uses `String(localized: .key)`. Keys with arguments become functions: `.restartApp(name)`.
3. For macOS terms, copy the exact translation macOS uses; system `.loctable` files under `/System/Library` hold them.

`Tests/Scripts/test_localization.py` fails when a string misses a language, a translation drops or adds a placeholder, or a key is unused. Swift tests run in English (the scheme sets the test language), so their assertions hold on a Mac set to any language.

## Safety audit

The audit greps `Sources`, `Tests`, and `project.yml` (`CFArrayGetValueAtIndex` skips `*.py` so policy tests can name that API, and still scans C and Objective-C) and fails the command when it finds:

- APIs that could inject, seize, or tap input (`CGEvent*`, `IOHIDPostEvent`, virtual HID devices, private `CGS*` symbols)
- Networking, analytics, or crash-upload APIs (`URLSession`, `Sentry`, `MetricKit`, and similar)
- `print`, `NSLog`, or `os_log` (use the `Log` pipeline instead)
- Key Content names (`KeyContent`, `rawReport`, `interpretedText`, `modifierState`) in the logging pipeline or at log call sites
- `CFArrayGetValueAtIndex`, which caused a use-after-free in optimized builds; bridge CF arrays to Swift arrays instead. SwiftLint's `no_cfarray_get_value` custom rule rejects the same API.

Because the pattern is a plain grep, even naming a type such as `CGSize` in `Sources` trips the `CGS*` rule.

## Pre-commit size limit

Turn on the repository hooks once per clone (worktrees share the setting):

```sh
git config core.hooksPath .githooks
```

`.githooks/pre-commit` rejects a commit when a staged file is over 20,000 bytes. Its error lists each file and explains how to split it. Only staged files are checked, so an existing large file fails the first time someone commits a change to it.

Binary files and paths marked `linguist-generated` or `linguist-vendored` in [`.gitattributes`](../.gitattributes) are exempt: the Xcode project, string catalogs, the Pencil design file, lockfiles, and vendored agent skills. Mark new generated or vendored paths there rather than splitting them.

## SwiftLint

Local checks and CI run the same command:

```sh
swiftlint lint --strict --quiet --no-cache --config .swiftlint.yml
```

- It checks all of `Sources`, including preview fixtures. A different SwiftLint version, any warning, or any error fails the check. There is no violation baseline.
- Default rules stay on. Size limits are raised so existing models and screens pass without a refactor while further growth still fails: 1000 lines per file, 800 per type body, 120 per function body. Type and identifier names may reach 60 characters so they can use full domain terms.
- Custom rules reject generic SwiftUI templates that have already been corrected in review: `ObservableObject`, GCD, `String(format:)`, SwiftUI `Picker(` (use `PopUpPicker`), `CFArrayGetValueAtIndex`, and the others listed in [`.swiftlint.yml`](../.swiftlint.yml). `Tests/Scripts/test_source_policy.py` fails if those rules are removed.
- Cyclomatic complexity ignores `switch` cases, so exhaustive enum mappings do not count; branches and loops still do.
- CI and the Release workflow download the portable macOS archive and verify its SHA-256, `c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0`.

To upgrade SwiftLint, change the version in `.swiftlint.yml` and the download URL and checksum in both `.github/workflows/ci.yml` and `.github/workflows/release.yml` together, then recheck the sources.
