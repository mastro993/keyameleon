import Testing
@testable import Keyameleon

@Test("First launch checks listen permission without requesting it")
@MainActor
func firstLaunchChecksListenPermissionWithoutRequestingIt() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .unknown)
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    #expect(permissionProvider.checkCount == 1)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(!model.canObservePhysicalKeyboards)
    #expect(!model.canRequestInputSources)
    #expect(model.guidedSetupStep == .permission)
}

@Test("Request Permission keeps denied status and does not complete setup")
@MainActor
func requestPermissionKeepsDeniedStatusAndDoesNotCompleteSetup() {
    let permissionProvider = SetupModelTestListenPermissionProvider(
        state: .unknown,
        stateAfterRequest: .denied
    )
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.requestPermission()

    #expect(permissionProvider.requestCount == 1)
    #expect(!model.isSetupComplete)
    #expect(!setupStore.hasCompletedGuidedSetup)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(model.guidedSetupStep == .permission)
}

@Test("Check Again refreshes permission without requesting it")
@MainActor
func checkAgainRefreshesPermissionWithoutRequestingIt() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .denied)
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    permissionProvider.state = .granted
    model.refreshPermission()

    #expect(permissionProvider.checkCount == 2)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.switchingStatus == .ready)
    #expect(model.canObservePhysicalKeyboards)
    #expect(model.canRequestInputSources)
}

@Test("Continue to Assignments advances step without completing setup")
@MainActor
func continueToAssignmentsAdvancesStepWithoutCompletingSetup() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .denied)
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.beginGuidedSetup()
    model.continueToAssignments()

    #expect(setupStore.hasStartedGuidedSetup)
    #expect(setupStore.guidedSetupStep == .assignments)
    #expect(model.guidedSetupStep == .assignments)
    #expect(!model.isSetupComplete)
    #expect(permissionProvider.requestCount == 0)
}

@Test("Finish Without Assignments completes setup and skips further steps")
@MainActor
func finishWithoutAssignmentsCompletesSetupAndSkipsFurtherSteps() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.continueToAssignments()
    model.finishWithoutAssignments()

    #expect(setupStore.hasCompletedGuidedSetup)
    #expect(model.isSetupComplete)
    #expect(model.guidedSetupStep == .assignments)
}

@Test("Interrupted setup restores completed decisions and resumes incomplete step")
@MainActor
func interruptedSetupRestoresCompletedDecisionsAndResumesIncompleteStep() {
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.markGuidedSetupStep(.assignments)

    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let identityKey = "identity:macos.keyboard.shared|anchor:serial:keyboard-a"
    recordStore.saveName(
        identityKey: identityKey,
        productName: "Test Keyboard",
        customName: "Desk"
    )
    recordStore.saveAssignment(
        identityKey: identityKey,
        productName: "Test Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [EligibleInputSource(identifier: "com.example.us", name: "U.S.")]
        ),
        physicalKeyboardRecordStore: recordStore
    )

    #expect(model.guidedSetupStep == .assignments)
    #expect(!model.isSetupComplete)

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 50)))

    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].name == "Desk")
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.us"
    )
}

func makeSetupModelHardwareFacts(
    serviceID: UInt64,
    identity: String = "macos.keyboard.shared",
    serialNumber: String? = "keyboard-a"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(
            rawValue: identity,
            isBuiltIn: false,
            serialNumber: serialNumber
        ),
        name: "Test Keyboard",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 500,
        productID: 100,
        modelNumber: "Model",
        serialNumber: serialNumber
    )
}

@MainActor
final class SetupModelTestListenPermissionProvider: ListenPermissionProviding {
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
final class SetupModelTestSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup = false
    private(set) var hasCompletedGuidedSetup = false
    private(set) var guidedSetupStep: GuidedSetupStep = .permission

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
        if guidedSetupStep != .assignments {
            guidedSetupStep = .permission
        }
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
}

@MainActor
final class SetupModelTestSystemSettingsOpener: SystemSettingsOpening {
    private(set) var openCount = 0

    func openSystemSettings() {
        openCount += 1
    }
}

@MainActor
final class SetupModelTestPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

@MainActor
final class SetupModelTestInputSourceProvider: InputSourceProviding {
    var inputSources: [EligibleInputSource]

    init(inputSources: [EligibleInputSource]) {
        self.inputSources = inputSources
    }

    func eligibleInputSources() -> [EligibleInputSource] {
        inputSources
    }
}
