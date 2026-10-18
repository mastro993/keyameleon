# Testing and CI

See [Testing](../testing.md). In short: one focused macOS 26 suite plus the safety audit ([ADR 0001](../adr/0001-product-validation.md)); hosted tests never start live surfaces ([ADR 0005](../adr/0005-hosted-unit-tests-skip-live-surface.md)); there is no UI-test target; Linux **Source policy** tests run on every pull request; and documentation-only changes skip the macOS job behind one stable required check.
