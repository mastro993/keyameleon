import AppKit

/// Side effects that help a person grant Input Monitoring.
@MainActor
protocol InputMonitoringRecovering: AnyObject {
    /// Opens Privacy & Security → Input Monitoring.
    func openSystemSettings()
    /// Quits and reopens Keyameleon. macOS applies an Input Monitoring grant
    /// only to processes started after it.
    func relaunch()
    /// Call once at launch. When the previous process relaunched for a grant
    /// and this fresh process still reads denied, the saved row cannot match
    /// this build (for example after a reinstall), so it is reset. Returns
    /// true when the decision is unknown again and a request will prompt.
    func resetStaleGrantAfterRelaunch() async -> Bool
}

@MainActor
final class SystemInputMonitoringRecovery: InputMonitoringRecovering {
    static let relaunchKey = "keyameleon.inputMonitoring.relaunchedForGrant"

    private let permissionProvider: any ListenPermissionProviding
    private let defaults: UserDefaults
    private let openURL: @MainActor (URL) -> Void
    private let startRelauncher: @MainActor () -> Bool
    private let terminate: @MainActor () -> Void
    private let resetGrant: @MainActor () async -> Bool

    init(
        permissionProvider: any ListenPermissionProviding,
        defaults: UserDefaults = .standard,
        openURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) },
        startRelauncher: @escaping @MainActor () -> Bool = SystemInputMonitoringRecovery.startRelauncher,
        terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        resetGrant: @escaping @MainActor () async -> Bool = SystemInputMonitoringRecovery.resetListenEventGrant
    ) {
        self.permissionProvider = permissionProvider
        self.defaults = defaults
        self.openURL = openURL
        self.startRelauncher = startRelauncher
        self.terminate = terminate
        self.resetGrant = resetGrant
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        ) else { return }
        openURL(url)
    }

    func relaunch() {
        // Without a relauncher, quitting would leave Keyameleon closed.
        guard startRelauncher() else { return }
        defaults.set(true, forKey: Self.relaunchKey)
        Log.debug(.app, "Relaunching to apply Input Monitoring")
        terminate()
    }

    func resetStaleGrantAfterRelaunch() async -> Bool {
        guard defaults.bool(forKey: Self.relaunchKey) else { return false }
        defaults.removeObject(forKey: Self.relaunchKey)
        guard permissionProvider.checkListenPermission() == .denied else { return false }

        guard await resetGrant() else {
            Log.warning(.app, "Could not reset the Input Monitoring decision")
            return false
        }
        Log.debug(.app, "Reset a stale Input Monitoring decision")
        return permissionProvider.checkListenPermission() == .unknown
    }

    /// Waits for this process to exit, releasing the single-instance lock,
    /// then reopens the same bundle.
    static func startRelauncher() -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = [
            "-c",
            "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
            Bundle.main.bundlePath,
            String(ProcessInfo.processInfo.processIdentifier)
        ]
        do {
            try process.run()
            return true
        } catch {
            Log.warning(.app, "Could not start the relauncher")
            return false
        }
    }

    /// Clears only Keyameleon's Input Monitoring row. No administrator
    /// password is needed for an app's own bundle identifier.
    static func resetListenEventGrant() async -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/tccutil")
            process.arguments = ["reset", "ListenEvent", bundleIdentifier]
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
