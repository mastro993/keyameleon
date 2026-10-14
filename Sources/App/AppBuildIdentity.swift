import Foundation

/// The identity a Keyameleon build runs under, decided by its bundle identifier.
///
/// Release builds, including every Official Release, use `dev.fedemas.keyameleon`.
/// Debug builds use `dev.fedemas.keyameleon.debug`, so macOS keeps a separate
/// Input Monitoring row and defaults domain for them, and they keep their own
/// data and logs ([ADR 0008](../../docs/adr/0008-separate-debug-identity.md)).
/// Both identities share the single-instance lock (ADR 0002).
enum AppBuildIdentity: Equatable, Sendable {
    case release
    case debug

    static let releaseBundleIdentifier = "dev.fedemas.keyameleon"
    static let current = AppBuildIdentity(bundleIdentifier: Bundle.main.bundleIdentifier)

    /// Any bundle identifier other than the release one is a Debug identity, so
    /// an unexpected build never opens the release's data.
    init(bundleIdentifier: String?) {
        self = bundleIdentifier == Self.releaseBundleIdentifier ? .release : .debug
    }

    /// The folder under Application Support and Logs. It follows the bundle
    /// identifier, never the display name, so renaming or localizing the app
    /// never moves user data.
    var storageFolderName: String {
        switch self {
        case .release: "Keyameleon"
        case .debug: "Keyameleon Dev"
        }
    }

    /// Only the release copies the pre-0.4.6 store from SwiftData's shared
    /// default path. That path can belong to another app, so a Debug store
    /// always starts empty.
    var importsLegacyStore: Bool {
        self == .release
    }
}
