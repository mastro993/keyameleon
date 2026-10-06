# One instance of each Keyameleon build per Mac

Keyameleon and Keyameleon (Dev) each permit one running instance across macOS login sessions, app locations, and versions. Production locks `/dev/null`; development locks `/dev/zero`. The two builds can run together. A second process of the same build exits before starting services or changing app state.

Each build owns its own preferences domain, SwiftData folder, logs folder, and installation integrity keychain service. Development uses the existing `dev.fedemas.keyameleon.development` bundle ID and `UserDefaults.standard`. Its SwiftData store starts empty in `~/Library/Application Support/Keyameleon (Dev)/default.store`; it never imports the production store. Existing development preferences remain in their current domain. Production keeps its existing data paths and legacy store migration.

Development does not start Sparkle. Production retains its update policy. Each build has its own Input Monitoring permission grant, controlled by macOS.

Ownership remains while a process runs, including when it does not respond. Exit, crash, force quit, logout, or restart releases ownership. An update helper can run while production runs, but a new production version starts only after the old one exits.
