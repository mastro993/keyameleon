# One Keyameleon instance per Mac

Keyameleon permits only one app instance on a Mac at a time, across all macOS login sessions, app locations, versions, Official Releases, and development builds. This machine-wide limit prevents concurrent Activity-Triggered Switching and app-state access.

The first process that gets exclusive ownership runs. All later launch attempts exit without a visible response or a change to the running process; direct executable and test launches return a nonzero status. The rule covers normal, forced, direct, and simultaneous launches, has no development or test bypass, and fails closed before Keyameleon starts services or changes app state.

Ownership remains while the process runs, including when it does not respond. Exit, crash, force quit, logout, or Mac restart releases ownership without a stale block. An update helper can run while Keyameleon runs, but a new Keyameleon version starts only after the old version exits.
