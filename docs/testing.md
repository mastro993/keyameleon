# Testing

Run the complete local check with:

```sh
./Scripts/run.sh test
```

This command runs the focused automated product tests on macOS 26 and the fast
safety audit. Tests should protect one distinct user-visible outcome or one
critical safety rule. Prefer domain and model seams. Use UI tests only when the
behavior cannot be checked below the UI boundary.

Keep these rules as hard failures:

- Keyameleon remains monitor-only and never injects or changes Physical Keyboard Events.
- Key Content does not enter saved data, Diagnostic Data, logs, network output, or crash state.
- Activity-Triggered Switching selects the exact Keyboard Assignment and verifies the result.

Do not add repeated suites, fixed event counts, participant quotas, qualification
evidence files, endurance runs, or performance thresholds without a real product
failure that needs them. Official Release artifact evidence remains separate.
