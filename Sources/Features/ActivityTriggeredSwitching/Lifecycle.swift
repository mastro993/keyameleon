import AppKit
import Carbon.HIToolbox

enum KeyameleonLifecycleEvent: Equatable, Sendable {
    case willSleep
    case didWake
    case sessionDidResignActive
    case sessionDidBecomeActive
    case protectedDataWillBecomeUnavailable
    case protectedDataDidBecomeAvailable
}

struct ProtectedStateSnapshot: Equatable, Sendable {
    let isSecureInputEnabled: Bool
    let isProtectedDataAvailable: Bool

    static let clear = ProtectedStateSnapshot(
        isSecureInputEnabled: false,
        isProtectedDataAvailable: true
    )
}

@MainActor
protocol ProtectedStateProviding: AnyObject {
    func currentProtectedState() -> ProtectedStateSnapshot
}

@MainActor
final class SystemProtectedStateProvider: ProtectedStateProviding {
    func currentProtectedState() -> ProtectedStateSnapshot {
        ProtectedStateSnapshot(
            isSecureInputEnabled: IsSecureEventInputEnabled(),
            isProtectedDataAvailable: NSApp.isProtectedDataAvailable
        )
    }
}

@MainActor
protocol KeyameleonLifecycleObserving: AnyObject {
    func start(onEvent: @escaping @MainActor (KeyameleonLifecycleEvent) -> Void)
    func stop()
}

/// Test double / no-op default when lifecycle observation is not started.
@MainActor
final class NoOpKeyameleonLifecycleObserver: KeyameleonLifecycleObserving {
    func start(onEvent: @escaping @MainActor (KeyameleonLifecycleEvent) -> Void) {}
    func stop() {}
}

@MainActor
final class SystemKeyameleonLifecycleObserver: KeyameleonLifecycleObserving {
    private let workspaceNotificationCenter: NotificationCenter
    private let applicationNotificationCenter: NotificationCenter
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var applicationObserverTokens: [NSObjectProtocol] = []
    private var onEvent: (@MainActor (KeyameleonLifecycleEvent) -> Void)?

    init(
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        applicationNotificationCenter: NotificationCenter = .default
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.applicationNotificationCenter = applicationNotificationCenter
    }

    func start(onEvent: @escaping @MainActor (KeyameleonLifecycleEvent) -> Void) {
        stop()
        self.onEvent = onEvent

        observe(
            in: workspaceNotificationCenter,
            storingIn: &workspaceObserverTokens,
            name: NSWorkspace.willSleepNotification,
            event: .willSleep
        )
        observe(
            in: workspaceNotificationCenter,
            storingIn: &workspaceObserverTokens,
            name: NSWorkspace.didWakeNotification,
            event: .didWake
        )
        observe(
            in: workspaceNotificationCenter,
            storingIn: &workspaceObserverTokens,
            name: NSWorkspace.sessionDidResignActiveNotification,
            event: .sessionDidResignActive
        )
        observe(
            in: workspaceNotificationCenter,
            storingIn: &workspaceObserverTokens,
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            event: .sessionDidBecomeActive
        )
        observe(
            in: applicationNotificationCenter,
            storingIn: &applicationObserverTokens,
            name: Notification.Name.NSApplicationProtectedDataWillBecomeUnavailable,
            event: .protectedDataWillBecomeUnavailable
        )
        observe(
            in: applicationNotificationCenter,
            storingIn: &applicationObserverTokens,
            name: Notification.Name.NSApplicationProtectedDataDidBecomeAvailable,
            event: .protectedDataDidBecomeAvailable
        )
    }

    func stop() {
        for token in workspaceObserverTokens {
            workspaceNotificationCenter.removeObserver(token)
        }
        workspaceObserverTokens.removeAll()

        for token in applicationObserverTokens {
            applicationNotificationCenter.removeObserver(token)
        }
        applicationObserverTokens.removeAll()
        onEvent = nil
    }

    private func observe(
        in center: NotificationCenter,
        storingIn tokens: inout [NSObjectProtocol],
        name: Notification.Name,
        event: KeyameleonLifecycleEvent
    ) {
        tokens.append(
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else {
                    return
                }

                Task { @MainActor in
                    self.onEvent?(event)
                }
            }
        )
    }
}
