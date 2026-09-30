# Testing

Run the complete local check with:

```sh
./Scripts/run.sh test
```

This command runs the safety audit, SwiftLint, and the focused automated product
tests on macOS 26. SwiftLint runs before the Xcode project generation and build.
The command runs Swift Testing and XCTest bundles serially, then kills
leftover Keyameleon processes whose executable is under `./build`. Tests should
protect one distinct user-visible outcome or one critical safety rule. Prefer
domain and model seams; this repository has no automated UI-test target.

## SwiftLint

Install SwiftLint **0.65.1** from its
[official release](https://github.com/realm/SwiftLint/releases/tag/0.65.1).
The portable macOS archive has SHA-256
`c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0`.
CI downloads that archive and verifies its checksum.

Run the source check without an Xcode build:

```sh
./Scripts/run.sh lint
```

Local checks and CI use `.swiftlint.yml` and the same command:

```sh
swiftlint lint --strict --quiet --no-cache --config .swiftlint.yml
```

The configuration pins the tool version and checks all of `Sources`, including
preview fixtures. A different version, a warning, or an error fails the check.
The default rules remain enabled. There is no saved violation baseline.

The project uses explicit size limits for its existing state models, SwiftUI
screens, and preview fixtures. Strict mode fails above 1000 lines per file,
800 lines per type body, or 120 lines per function body. These limits avoid a
behavioral refactor solely to satisfy SwiftLint's smaller default limits while
still detecting further growth. Type and identifier names allow 60 characters
so that names can use the full domain vocabulary. The default minimum lengths
and character checks remain active.

Cyclomatic complexity keeps the default limits but excludes `switch` cases.
Exhaustive domain-enum mappings do not increase the count. Conditional branches
and loops still count. No correctness rule is disabled by this policy.

When updating SwiftLint, update the version in `.swiftlint.yml` and the CI
download URL and checksum together. Recheck the source baseline before changing
the pin.

## Product tests and CI

Hosted unit-test processes (`KeyameleonSwiftTesting`, `KeyameleonXCTest`) must
not start live CoreHID observation or the menu-bar status item. Detect them
with `XCTestConfigurationFilePath` or `XCTestBundlePath`. See
`docs/adr/0005-hosted-unit-tests-skip-live-surface.md`.

Hosted tests and Xcode previews use in-memory SwiftData storage. Store relocation
tests use disposable directories and must never migrate the user's real data.

CI uses one stable required check, `Required CI gate`, with two paths:

- Changes outside the paths in CI's `Check whether code changed` step, such as
  documentation-only changes, do not run tests or use a macOS runner.
- Changes to those paths, including `.swiftlint.yml`, `Scripts`,
  `.github/workflows/ci.yml`, and `.github/workflows/release.yml`, run SwiftLint,
  the complete macOS product tests, and the safety audit.

The macOS job has an eight-minute limit and no automatic retry. A maintainer can
rerun an infrastructure failure after inspection. The `main` branch ruleset
requires `Required CI gate` from GitHub Actions for pull-request merges. Do not
require the conditional `Build and test` job: skipped jobs can satisfy a required
check even when the aggregate gate fails. Repository administrators retain the
emergency override.

Keep these rules as hard failures:

- Keyameleon remains monitor-only and never injects or changes Physical Keyboard Events.
- Key Content does not enter saved data, log files, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

Do not add repeated suites, fixed event counts, participant quotas, qualification
evidence files, endurance runs, or performance thresholds without a real product
failure that needs them. Official Release artifact evidence remains separate.
