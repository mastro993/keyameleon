import AppKit

/// Reports each app macOS makes active. Activity-Triggered Switching decides
/// which activations are App Activations.
@MainActor
protocol FrontmostAppObserving: AnyObject {
    /// The app active right now, if it has a bundle identifier.
    var activeApp: FrontmostApp? { get }
    func start(onActivate: @escaping @MainActor (FrontmostApp) -> Void)
    func stop()
}

/// Test double / no-op default when app activation is not observed.
@MainActor
final class NoOpFrontmostAppObserver: FrontmostAppObserving {
    var activeApp: FrontmostApp? { nil }
    func start(onActivate: @escaping @MainActor (FrontmostApp) -> Void) {}
    func stop() {}
}

/// Observes `NSWorkspace.didActivateApplicationNotification`. It needs no permission.
@MainActor
final class SystemFrontmostAppObserver: FrontmostAppObserving {
    private let workspace: NSWorkspace
    private var token: NSObjectProtocol?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var activeApp: FrontmostApp? {
        workspace.frontmostApplication.flatMap(Self.frontmostApp)
    }

    func start(onActivate: @escaping @MainActor (FrontmostApp) -> Void) {
        stop()
        token = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
                .flatMap(Self.frontmostApp)
            guard let app else { return }
            Task { @MainActor in
                onActivate(app)
            }
        }
    }

    func stop() {
        if let token {
            workspace.notificationCenter.removeObserver(token)
        }
        token = nil
    }

    private nonisolated static func frontmostApp(_ application: NSRunningApplication) -> FrontmostApp? {
        guard let bundleIdentifier = application.bundleIdentifier else { return nil }
        return FrontmostApp(
            bundleIdentifier: bundleIdentifier,
            name: application.localizedName ?? bundleIdentifier
        )
    }
}
