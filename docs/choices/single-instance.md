# Single instance

Only one Keyameleon process runs per Mac, across users, locations, versions, and Debug builds ([ADR 0002](../adr/0002-one-keyameleon-instance-per-mac.md)). Debug builds have their own bundle ID but share this lock, so two switchers never fight over the Input Source ([ADR 0008](../adr/0008-separate-debug-identity.md)). The lock is an advisory lock on `/dev/null`, which every user can open and nobody can delete. Later launches exit silently, and direct executable launches return a nonzero status.
