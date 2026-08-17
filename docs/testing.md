# Testing

Run the complete local check with:

```sh
./Scripts/run.sh test
```

This command runs the focused automated product tests on macOS 26 and the fast
safety audit. It builds the test products once, runs the lifecycle UI test
first, and then runs the remaining test bundles serially. After each
`xcodebuild` test run it kills leftover Keyameleon processes whose executable
is under `./build`. Tests should protect one distinct user-visible outcome or
one critical safety rule. Prefer domain and model seams. Use UI tests only
when the behavior cannot be checked below the UI boundary.

Hosted unit-test processes (`KeyameleonSwiftTesting`, `KeyameleonXCTest`) must
not start live CoreHID observation or the menu-bar status item. Detect them
with `XCTestConfigurationFilePath` or `XCTestBundlePath`. UI tests launch the
real app and stay live. See `docs/adr/0005-hosted-unit-tests-skip-live-surface.md`.

CI uses one stable required gate with two paths:

- Pull requests and `main` commits that do not change app source, product tests,
  the test runner, project or package files, or the CI workflow do not run tests
  and do not use a macOS runner.
- Changes to those code paths run the complete macOS product tests and safety
  audit.

The macOS job has an eight-minute limit and no automatic retry. A maintainer can
rerun an infrastructure failure after inspection. GitHub branch rules require
the stable gate for pull-request merges; repository administrators retain the
emergency override.

Keep these rules as hard failures:

- Keyameleon remains monitor-only and never injects or changes Physical Keyboard Events.
- Key Content does not enter saved data, Diagnostic Data, logs, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

Do not add repeated suites, fixed event counts, participant quotas, qualification
evidence files, endurance runs, or performance thresholds without a real product
failure that needs them. Official Release artifact evidence remains separate.
