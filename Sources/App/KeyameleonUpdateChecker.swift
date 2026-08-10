import Foundation
import Sparkle

@MainActor
protocol UpdateChecking: AnyObject {
    /// Starts the updater so launch checks obey the 24-hour bound.
    func start()
    /// User-initiated check; always allowed when the updater can check.
    func checkForUpdates()
    var canCheckForUpdates: Bool { get }
}

/// Sparkle 2 adapter. Configuration lives in Info.plist; this only starts and exposes checks.
@MainActor
final class SparkleUpdateChecker: NSObject, UpdateChecking, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController!
    private var didStart = false

    override init() {
        super.init()
        // startingUpdater: false — start after configuration; Official Release supplies EdDSA key.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        guard didStart else {
            return false
        }
        return controller.updater.canCheckForUpdates
    }

    func start() {
        guard !didStart else {
            return
        }

        // Enforce privacy-bound request shape before any network work.
        controller.updater.sendsSystemProfile = KeyameleonUpdatePolicy.sendsSystemProfile
        controller.updater.httpHeaders = nil
        controller.updater.userAgentString = defaultUserAgentString()

        do {
            try controller.updater.start()
            didStart = true
        } catch {
            // Missing EdDSA key or feed is expected before Official Release tooling lands.
            // Keep the process alive; manual checks stay unavailable until configuration is complete.
            didStart = false
        }
    }

    func checkForUpdates() {
        guard didStart, controller.updater.canCheckForUpdates else {
            return
        }
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    func feedParameters(
        for updater: SPUUpdater,
        sendingSystemProfile: Bool
    ) -> [[String: String]] {
        // Empty: no Keyameleon-generated user or device identifier parameters.
        _ = updater
        _ = sendingSystemProfile
        return []
    }

    private func defaultUserAgentString() -> String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
        return "\(KeyameleonAppMetadata.displayName)/\(version)"
    }
}
