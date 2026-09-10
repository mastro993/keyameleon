import Foundation
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
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
    #expect(!model.activityTriggeredSwitching.outcome.switchingStatus.allowsActivityTriggeredSwitching)
    #expect(!model.activityTriggeredSwitching.outcome.switchingStatus.allowsPhysicalKeyboardDiscovery)
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
    let settingsOpener = SetupModelTestSystemSettingsOpener()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: settingsOpener
    )

    model.activityTriggeredSwitching.start()
    model.requestPermission()

    #expect(permissionProvider.requestCount == 1)
    #expect(settingsOpener.openCount == 0)
    #expect(model.isSetupComplete == false)
    #expect(setupStore.hasCompletedGuidedSetup == false)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
    #expect(model.guidedSetupStep == .permission)
    #expect(model.isWaitingForListenPermission)
}

@Test("Request Permission never opens System Settings")
@MainActor
func requestPermissionDoesNotOpenSystemSettingsWhenListenPermissionIsGranted() {
    let permissionProvider = SetupModelTestListenPermissionProvider(
        state: .unknown,
        stateAfterRequest: .granted
    )
    let settingsOpener = SetupModelTestSystemSettingsOpener()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: settingsOpener
    )

    model.activityTriggeredSwitching.start()
    model.requestPermission()

    #expect(permissionProvider.requestCount == 1)
    #expect(settingsOpener.openCount == 0)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
}

@Test("Info.plist declares Input Monitoring usage description")
func infoPlistDeclaresInputMonitoringUsageDescription() throws {
    let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let infoPlistURL = testsDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/App/Info.plist")
    let data = try Data(contentsOf: infoPlistURL)
    let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )
    let usageDescription = try #require(
        plist["NSInputMonitoringUsageDescription"] as? String
    )
    #expect(usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
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
    startAndCheck(model)

    #expect(permissionProvider.checkCount == 2)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus.allowsActivityTriggeredSwitching)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus.allowsPhysicalKeyboardDiscovery)
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

@Test("Begin Guided setup advances past permission when listen permission is already granted")
@MainActor
func beginGuidedSetupAdvancesWhenListenPermissionIsGranted() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.beginGuidedSetup()

    #expect(setupStore.hasStartedGuidedSetup)
    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
    #expect(model.isWaitingForListenPermission == false)
}

@Test("Relaunch after listen permission grant resumes at assignments")
@MainActor
func relaunchAfterListenPermissionGrantResumesAtAssignments() {
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.markGuidedSetupStep(.permission)
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.beginGuidedSetup()

    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
}

@Test("Check Again advances Guided setup when listen permission is granted")
@MainActor
func checkAgainAdvancesGuidedSetupWhenListenPermissionIsGranted() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .denied)
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.beginGuidedSetup()
    #expect(model.guidedSetupStep == .permission)

    permissionProvider.state = .granted
    startAndCheck(model)
    model.advanceIfPermissionGranted()

    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
}

@Test("Completing setup notifies once")
@MainActor
func completingSetupNotifiesOnce() {
    var completionCount = 0
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )
    model.onGuidedSetupCompleted = {
        completionCount += 1
    }

    model.continueToAssignments()
    model.completeSetup()
    model.completeSetup()

    #expect(model.isSetupComplete)
    #expect(completionCount == 1)
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

    startAndCheck(model)
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
    private(set) var isActivityTriggeredSwitchingPaused = false
    private(set) var hasEvaluatedBuiltInIdentityMigration = false

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

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
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
