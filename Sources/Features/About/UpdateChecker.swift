import AppKit
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
final class SparkleUpdateChecker: NSObject, UpdateChecking, SPUUpdaterDelegate,
    @preconcurrency SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController!
    private var didStart = false
    /// False during Guided setup, which keeps its Dock icon after an update session.
    private let isMenuBarOnly: @MainActor () -> Bool

    init(isMenuBarOnly: @escaping @MainActor () -> Bool = { true }) {
        self.isMenuBarOnly = isMenuBarOnly
        super.init()
        // startingUpdater: false — start after configuration; Official Release supplies EdDSA key.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    var canCheckForUpdates: Bool {
        guard didStart else {
            return false
        }
        return controller.updater.canCheckForUpdates
    }

    func start() {
        // Sparkle would start a signed build without the Official Release EdDSA key and trust
        // Apple code signing alone. Keyameleon updates only builds that carry the key.
        guard !didStart, Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else {
            return
        }

        // Enforce privacy-bound request shape before any network work.
        controller.updater.sendsSystemProfile = UpdatePolicy.sendsSystemProfile
        controller.updater.httpHeaders = nil
        controller.updater.userAgentString = defaultUserAgentString()

        do {
            try controller.updater.start()
            didStart = true
        } catch {
            // An invalid key or feed keeps the process alive; manual checks stay unavailable.
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

    // MARK: - SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else {
            return
        }
        // Sparkle shows its own alert for scheduled updates; the Dock entry only makes it findable.
        NSApp.setActivationPolicy(.regular)
        NSApp.dockTile.badgeLabel = "1"
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSApp.dockTile.badgeLabel = ""
    }

    func standardUserDriverWillFinishUpdateSession() {
        NSApp.dockTile.badgeLabel = ""
        if isMenuBarOnly() {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func defaultUserAgentString() -> String {
        let applicationName =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Keyameleon"
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
        return "\(applicationName)/\(version)"
    }
}
