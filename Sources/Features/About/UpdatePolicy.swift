import Foundation

/// Product rules for user-approved, privacy-bounded updates.
enum KeyameleonUpdatePolicy {
    /// Sparkle may check on launch at most this often.
    static let minimumCheckInterval: TimeInterval = 24 * 60 * 60

    /// Automatic download/install is never allowed. User approves every installation.
    static let allowsAutomaticInstallation = false

    /// Critical updates may warn; they must not bypass user approval.
    static let criticalUpdatesBypassUserApproval = false

    /// No Keyameleon-generated user or device identifier on update requests.
    static let allowsKeyameleonGeneratedIdentifiers = false

    /// Anonymous system profiling is off.
    static let sendsSystemProfile = false

    /// Official Release appcast published on the Keyameleon GitHub Pages site.
    static let feedURLString =
        "https://mastro993.github.io/Keyameleon/appcast.xml"

    static func shouldCheckForUpdates(
        lastCheckDate: Date?,
        now: Date = Date(),
        minimumInterval: TimeInterval = minimumCheckInterval
    ) -> Bool {
        guard let lastCheckDate else {
            return true
        }

        return now.timeIntervalSince(lastCheckDate) >= minimumInterval
    }
}
