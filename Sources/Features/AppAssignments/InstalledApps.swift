import AppKit

/// Looks up apps on this Mac for App Assignments.
@MainActor
protocol InstalledAppsProviding: AnyObject {
    /// Running apps that show in the Dock.
    func runningApps() -> [InstalledApp]
    /// Nil when the app is not installed.
    func url(forBundleIdentifier bundleIdentifier: String) -> URL?
    /// Nil when the bundle at `url` has no bundle identifier.
    func app(at url: URL) -> InstalledApp?
}

@MainActor
final class SystemInstalledApps: InstalledAppsProviding {
    func runningApps() -> [InstalledApp] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.activationPolicy == .regular,
                  let bundleIdentifier = application.bundleIdentifier,
                  let url = application.bundleURL else {
                return nil
            }
            return InstalledApp(
                bundleIdentifier: bundleIdentifier,
                name: application.localizedName ?? FileManager.default.displayName(atPath: url.path),
                url: url
            )
        }
    }

    func url(forBundleIdentifier bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func app(at url: URL) -> InstalledApp? {
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return InstalledApp(
            bundleIdentifier: bundleIdentifier,
            name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name,
            url: url
        )
    }
}

/// Test and preview double: a fixed set of installed and running apps.
@MainActor
final class InMemoryInstalledApps: InstalledAppsProviding {
    private let installed: [InstalledApp]
    private let running: Set<String>

    init(installed: [InstalledApp] = [], running: Set<String> = []) {
        self.installed = installed
        self.running = running
    }

    func runningApps() -> [InstalledApp] {
        installed.filter { running.contains($0.bundleIdentifier) }
    }

    func url(forBundleIdentifier bundleIdentifier: String) -> URL? {
        installed.first { $0.bundleIdentifier == bundleIdentifier }?.url
    }

    func app(at url: URL) -> InstalledApp? {
        installed.first { $0.url == url }
    }
}
