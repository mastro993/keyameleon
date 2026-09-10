import AppKit
@testable import Keyameleon

@MainActor
func makeApplicationTestDelegate(
    permissionProvider: any ListenPermissionProviding = ApplicationTestListenPermissionProvider(
        state: .granted
    ),
    setupStore: any SetupDecisionStoring = ApplicationTestSetupDecisionStore(),
    updateChecker: any UpdateChecking = ApplicationTestUpdateChecker(),
    physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering = NoOpPhysicalKeyboardDiscoverer(),
    startsUpdaterOnLaunch: Bool = false,
    startsApplicationSurfaceOnLaunch: Bool = true
) -> KeyameleonApplicationDelegate {
    KeyameleonApplicationDelegate(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        physicalKeyboardDiscoverer: physicalKeyboardDiscoverer,
        physicalKeyboardEventObserver: NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: NoOpInputSourceChangeObserver(),
        lifecycleObserver: NoOpKeyameleonLifecycleObserver(),
        updateChecker: updateChecker,
        startsUpdaterOnLaunch: startsUpdaterOnLaunch,
        startsApplicationSurfaceOnLaunch: startsApplicationSurfaceOnLaunch,
        singleInstanceLock: makeApplicationTestSingleInstanceLock()
    )
}

func makeApplicationTestSingleInstanceLock() -> KeyameleonSingleInstanceLock {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyameleonApplicationTests-\(UUID().uuidString).lock")
    guard let lock = KeyameleonSingleInstanceLock.acquire(at: url) else {
        fatalError("Could not acquire test single-instance lock")
    }
    try? FileManager.default.removeItem(at: url)
    return lock
}

@MainActor
func stopApplicationTestSurface(_ delegate: KeyameleonApplicationDelegate) {
    delegate.applicationWillTerminate(
        Notification(name: NSApplication.willTerminateNotification)
    )
}

@MainActor
final class ApplicationTestPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class MenuBarPanelTestAnchorWindow {
    private let window: NSWindow
    let positioningView: NSView

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 24),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.orderFrontRegardless()
        self.window = window
        self.positioningView = window.contentView!
    }

    func close() {
        window.close()
    }
}

@MainActor
final class ApplicationTestUpdateChecker: UpdateChecking {
    private(set) var startCallCount = 0
    var canCheckForUpdates = false

    func start() {
        startCallCount += 1
        canCheckForUpdates = true
    }

    func checkForUpdates() {}
}

@MainActor
final class ApplicationTestListenPermissionProvider: ListenPermissionProviding {
    var state: ListenPermissionState
    private(set) var checkCount = 0

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        checkCount += 1
        return state
    }

    func requestListenPermission() -> Bool {
        state == .granted
    }
}

@MainActor
final class ApplicationTestSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup: Bool
    private(set) var hasCompletedGuidedSetup: Bool
    private(set) var guidedSetupStep: GuidedSetupStep
    private(set) var isActivityTriggeredSwitchingPaused = false
    private(set) var hasEvaluatedBuiltInIdentityMigration = false

    init(
        hasStartedGuidedSetup: Bool = false,
        hasCompletedGuidedSetup: Bool = true,
        guidedSetupStep: GuidedSetupStep = .assignments
    ) {
        self.hasStartedGuidedSetup = hasStartedGuidedSetup
        self.hasCompletedGuidedSetup = hasCompletedGuidedSetup
        self.guidedSetupStep = guidedSetupStep
    }

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasStartedGuidedSetup = true
        hasCompletedGuidedSetup = true
        guidedSetupStep = .assignments
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }
}
