import Testing
@testable import Keyameleon

@Test("First launch checks listen permission without requesting it")
@MainActor
func firstLaunchChecksListenPermissionWithoutRequestingIt() {
    let permissionProvider = TestListenPermissionProvider(state: .unknown)
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: TestSetupDecisionStore(),
        systemSettingsOpener: TestSystemSettingsOpener()
    )

    #expect(permissionProvider.checkCount == 1)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(!model.canObservePhysicalKeyboards)
    #expect(!model.canRequestInputSources)
}

@Test("Request Permission completes setup and keeps denied status safe")
@MainActor
func requestPermissionCompletesSetupAndKeepsDeniedStatusSafe() {
    let permissionProvider = TestListenPermissionProvider(
        state: .unknown,
        stateAfterRequest: .denied
    )
    let setupStore = TestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: TestSystemSettingsOpener()
    )

    model.requestPermission()

    #expect(permissionProvider.requestCount == 1)
    #expect(model.isSetupComplete)
    #expect(setupStore.hasCompletedGuidedSetup)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(!model.canObservePhysicalKeyboards)
    #expect(!model.canRequestInputSources)
}

@Test("Check Again refreshes permission without requesting it")
@MainActor
func checkAgainRefreshesPermissionWithoutRequestingIt() {
    let permissionProvider = TestListenPermissionProvider(state: .denied)
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: TestSetupDecisionStore(),
        systemSettingsOpener: TestSystemSettingsOpener()
    )

    permissionProvider.state = .granted
    model.refreshPermission()

    #expect(permissionProvider.checkCount == 2)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.switchingStatus == .ready)
    #expect(model.canObservePhysicalKeyboards)
    #expect(model.canRequestInputSources)
}

@Test("Continuing without permission persists setup but not transient status")
@MainActor
func continuingWithoutPermissionPersistsSetupButNotTransientStatus() {
    let permissionProvider = TestListenPermissionProvider(state: .denied)
    let setupStore = TestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: TestSystemSettingsOpener()
    )

    model.beginGuidedSetup()
    model.completeSetup()

    #expect(setupStore.hasStartedGuidedSetup)
    #expect(setupStore.hasCompletedGuidedSetup)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(permissionProvider.requestCount == 0)
}

@MainActor
private final class TestListenPermissionProvider: ListenPermissionProviding {
    var state: ListenPermissionState
    private let stateAfterRequest: ListenPermissionState
    private(set) var checkCount = 0
    private(set) var requestCount = 0

    init(
        state: ListenPermissionState,
        stateAfterRequest: ListenPermissionState = .granted
    ) {
        self.state = state
        self.stateAfterRequest = stateAfterRequest
    }

    func checkListenPermission() -> ListenPermissionState {
        checkCount += 1
        return state
    }

    func requestListenPermission() -> Bool {
        requestCount += 1
        state = stateAfterRequest
        return state == .granted
    }
}

@MainActor
private final class TestSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup = false
    private(set) var hasCompletedGuidedSetup = false

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupCompleted() {
        hasCompletedGuidedSetup = true
    }
}

@MainActor
private final class TestSystemSettingsOpener: SystemSettingsOpening {
    private(set) var openCount = 0

    func openSystemSettings() {
        openCount += 1
    }
}
