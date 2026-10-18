# Testing

## Run the tests

```sh
./Scripts/run.sh test
```

This runs the safety audit, SwiftLint, the Python script tests, and then the Swift Testing and XCTest bundles, one after the other, on macOS 26. Afterwards it stops any leftover Keyameleon process whose executable is the Debug app or the test host under `./build`, and unregisters the test host from LaunchServices so Quit & Reopen cannot open it.

Hosted tests launch Keyameleon itself, so **quit any running Keyameleon first**; otherwise the test host exits under the single-instance lock. Tests use ad hoc signing, need no certificate, and build into `./build/test`, so they never replace the signed app from `run.sh open`. The test host runs under the Debug identity, `dev.fedemas.keyameleon.debug` ([ADR 0008](adr/0008-separate-debug-identity.md)). See [Development](development.md) for setup and SwiftLint policy.

## What to test

- Each test protects one distinct user-visible outcome or one critical safety rule.
- Prefer Swift Testing in `Tests/SwiftTesting` for domain and model seams. Use XCTest in `Tests/XCTest` only for AppKit shell contracts. There is no UI-test target.
- Do not test private counters or implementation wiring.
- Do not add repeated suites, fixed event counts, participant quotas, qualification evidence files, endurance runs, or performance thresholds unless a real product failure needs them ([ADR 0001](adr/0001-product-validation.md)).

These rules are hard failures:

- Keyameleon stays monitor-only: it never injects or changes Physical Keyboard Events.
- Key Content never enters saved data, log files, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

### Test environment rules

- Hosted test processes (`KeyameleonSwiftTesting`, `KeyameleonXCTest`) must not start CoreHID observation, the lifecycle observer, the status item, Guided setup, or Sparkle. Detect them with `XCTestConfigurationFilePath` or `XCTestBundlePath` ([ADR 0005](adr/0005-hosted-unit-tests-skip-live-surface.md)).
- Tests run in English and the U.S. region: the scheme's test action sets both, so copy assertions hold whatever language the Mac uses. Translations are checked by `Tests/Scripts/test_localization.py` and `LocalizationTests.swift`.
- Hosted app startup and Xcode previews use in-memory SwiftData storage. Store relocation and persistence-failure tests use disposable directories and never touch the user's real data.
- Saved Physical Keyboard changes are tested through `SavedPhysicalKeyboardChanges` with the real SwiftData adapters: rollback, exact Retry, blocked competing changes, and notifications after commit for rename and assignment. Model tests cover the displayed failure and recovery. `ManualDesignationTests` seeds designations the way earlier versions saved them and checks that authentic evidence is honored and tampered evidence is not.

## Continuous integration

The `CI` workflow reports one required check, **Required CI gate**, on every pull request and every push to `main`:

- **Source policy** always runs on Ubuntu: `Tests/Scripts/test_source_policy.py`, `test_ci.py`, `test_localization.py`, and `test_pre_commit.py`. These catch Debug/Release identity merges, a capitalized Sparkle feed path, SwiftUI `Picker` in Settings, missing translations, and a broken [pre-commit token limit](development.md#pre-commit-token-limit) without a macOS runner.
- **Build-affecting changes** also run `./Scripts/run.sh test` on a `macos-26` runner. These include `Sources`, `Resources`, `Keyameleon-icon.icon`, `LICENSE` and `THIRD_PARTY_NOTICES.md` (they are bundled in the app), `Tests`, `Scripts`, `project.yml`, the Xcode project and package files, `.swiftlint.yml`, and both workflow files. The `Check whether code changed` step in [`ci.yml`](../.github/workflows/ci.yml) holds the exact list.
- **Everything else**, such as documentation, skips the macOS job. The policy job still runs.

The macOS job has an eight-minute limit and no automatic retry; a maintainer reruns infrastructure failures after inspection. The `main` ruleset requires **Required CI gate**. Do not require the conditional `Build and test` job instead: a skipped job can satisfy a required check even when the gate fails.

## Manual verification

Unit tests cannot prove real permission grants, native menu tracking, display placement, or VoiceOver. After changing one of the areas below, run `./Scripts/run.sh test`, then work through its checklist in the running app (`./Scripts/run.sh open`).

- [Input Monitoring persistence](testing/manual-input-monitoring.md#input-monitoring-persistence)
- [Guided setup](testing/manual-guided-setup-and-settings.md#guided-setup)
- [Settings](testing/manual-guided-setup-and-settings.md#settings)
- [Menu bar menu](testing/manual-menu-and-switching.md#menu-bar-menu)
- [External Input Source Changes](testing/manual-menu-and-switching.md#external-input-source-changes)
- [App Assignments](testing/manual-menu-and-switching.md#app-assignments)
- [Automation](testing/manual-menu-and-switching.md#automation)
- [Input Monitoring recovery](testing/manual-input-monitoring.md#input-monitoring-recovery)
