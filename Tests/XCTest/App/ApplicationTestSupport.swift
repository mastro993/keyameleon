import AppKit
@testable import Keyameleon

@MainActor
func makeApplicationTestDelegate(
    permissionProvider: any ListenPermissionProviding = ApplicationTestListenPermissionProvider(
        state: .granted
    ),
    setupStore: any SetupDecisionStoring = ApplicationTestSetupDecisionStore(),
    inputMonitoringRecovery: any InputMonitoringRecovering = ApplicationTestInputMonitoringRecovery(),
    updateChecker: any UpdateChecking = ApplicationTestUpdateChecker(),
    physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering = NoOpPhysicalKeyboardDiscoverer(),
    startsUpdaterOnLaunch: Bool = false,
    startsApplicationSurfaceOnLaunch: Bool = true
) -> ApplicationDelegate {
    ApplicationDelegate(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        inputMonitoringRecovery: inputMonitoringRecovery,
        physicalKeyboardDiscoverer: physicalKeyboardDiscoverer,
        physicalKeyboardEventObserver: NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: NoOpInputSourceChangeObserver(),
        lifecycleObserver: NoOpLifecycleObserver(),
        updateChecker: updateChecker,
        startsUpdaterOnLaunch: startsUpdaterOnLaunch,
        startsApplicationSurfaceOnLaunch: startsApplicationSurfaceOnLaunch,
        singleInstanceLock: makeApplicationTestSingleInstanceLock()
    )
}

func makeApplicationTestSingleInstanceLock() -> SingleInstanceLock {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ApplicationTests-\(UUID().uuidString).lock")
    guard let lock = SingleInstanceLock.acquire(at: url) else {
        fatalError("Could not acquire test single-instance lock")
    }
    try? FileManager.default.removeItem(at: url)
    return lock
}

@MainActor
func stopApplicationTestSurface(_ delegate: ApplicationDelegate) {
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
final class ApplicationTestUpdateChecker: UpdateChecking {
    private(set) var startCallCount = 0
    private(set) var checkCallCount = 0
    var canCheckForUpdates = false

    func start() {
        startCallCount += 1
        canCheckForUpdates = true
    }

    func checkForUpdates() {
        checkCallCount += 1
        canCheckForUpdates = false
    }
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
        guidedSetupStep = .ready
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }
}

@MainActor
final class ApplicationTestInputMonitoringRecovery: InputMonitoringRecovering {
    private(set) var openCount = 0
    private(set) var relaunchCount = 0

    func openSystemSettings() {
        openCount += 1
    }

    func relaunch() {
        relaunchCount += 1
    }

    func resetStaleGrantAfterRelaunch() async -> Bool { false }
}
