import Foundation
import Testing
@testable import Keyameleon

@Test("Hidden connection snapshot advances when saved-record reads fail")
@MainActor
func hiddenConnectionUpdatesDespiteSavedRecordReadFailure() throws {
    let facts = makeSetupModelHardwareFacts(serviceID: 503)
    let key = try #require(PhysicalKeyboardExclusionKey.key(for: facts))
    let exclusions = InMemoryPhysicalKeyboardExclusionStore()
    exclusions.exclude(SavedPhysicalKeyboardExclusion(key: key, name: "Test Keyboard"))
    let session = SwiftDataPersistenceSession(openContainer: {
        throw CocoaError(.fileReadNoPermission)
    })
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: session),
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session),
        exclusionStore: exclusions
    )
    model.activityTriggeredSwitching.start()
    discoverer.emit(.connected(facts))
    #expect(model.persistenceError != nil)
    #expect(model.connectedExcludedKeyboardKeys == [key])
    discoverer.emit(.disconnected(serviceID: facts.serviceID))
    #expect(model.connectedExcludedKeyboardKeys.isEmpty)
}

@Test("First launch checks listen permission without requesting it")
@MainActor
func firstLaunchChecksListenPermissionWithoutRequestingIt() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .unknown)
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    #expect(permissionProvider.checkCount == 1)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
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
    let settingsOpener = SetupModelTestInputMonitoringRecovery()
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        inputMonitoringRecovery: settingsOpener
    )

    model.activityTriggeredSwitching.start()
    model.requestPermission()

    #expect(permissionProvider.requestCount == 1)
    #expect(settingsOpener.openCount == 0)
    #expect(model.isSetupComplete == false)
    #expect(setupStore.hasCompletedGuidedSetup == false)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
    #expect(model.guidedSetupStep == .permission)
    let actions = model.activityTriggeredSwitching.outcome.availableActions
    #expect(actions.isSuperset(of: [.openSystemSettings, .relaunch]))
    #expect(!actions.contains(.requestPermission))
}

@Test("Request Permission never opens System Settings")
@MainActor
func requestPermissionDoesNotOpenSystemSettingsWhenListenPermissionIsGranted() {
    let permissionProvider = SetupModelTestListenPermissionProvider(
        state: .unknown,
        stateAfterRequest: .granted
    )
    let settingsOpener = SetupModelTestInputMonitoringRecovery()
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: settingsOpener
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
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    permissionProvider.state = .granted
    startAndCheck(model)

    #expect(permissionProvider.checkCount == 2)
    #expect(permissionProvider.requestCount == 0)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus.allowsPhysicalKeyboardDiscovery)
}

@Test("Permissions cannot advance while access is denied")
@MainActor
func permissionCannotBeSkippedWithoutAccess() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .denied)
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    model.beginGuidedSetup()
    model.continueToAssignments()

    #expect(setupStore.hasStartedGuidedSetup)
    #expect(setupStore.guidedSetupStep == .permission)
    #expect(model.guidedSetupStep == .permission)
    #expect(!model.isSetupComplete)
    #expect(permissionProvider.requestCount == 0)
}

@Test("Completing setup without Keyboard Assignments records completion")
@MainActor
func completingSetupWithoutAssignmentsRecordsCompletion() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    model.beginGuidedSetup()
    model.continueToReady()
    model.completeSetup(destination: .menuBar)

    #expect(setupStore.hasCompletedGuidedSetup)
    #expect(model.isSetupComplete)
    #expect(model.guidedSetupStep == .ready)
}

@Test("Begin Guided setup advances past permission when listen permission is already granted")
@MainActor
func beginGuidedSetupAdvancesWhenListenPermissionIsGranted() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    model.beginGuidedSetup()

    #expect(setupStore.hasStartedGuidedSetup)
    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
}

@Test("Relaunch after listen permission grant resumes at assignments")
@MainActor
func relaunchAfterListenPermissionGrantResumesAtAssignments() {
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.markGuidedSetupStep(.permission)
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
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
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )

    model.beginGuidedSetup()
    #expect(model.guidedSetupStep == .permission)

    permissionProvider.state = .granted
    startAndCheck(model)
    model.advanceIfPermissionGranted()

    #expect(model.guidedSetupStep == .assignments)
    #expect(model.isSetupComplete == false)
}

@Test("A grant made in System Settings advances setup without another request")
@MainActor
func grantInSystemSettingsAdvancesSetup() async throws {
    let permission = SetupModelTestListenPermissionProvider(state: .denied)
    let model = SetupModel(
        permissionProvider: permission,
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    model.activityTriggeredSwitching.start()
    defer { model.activityTriggeredSwitching.stop() }
    model.beginGuidedSetup()
    #expect(model.guidedSetupStep == .permission)

    permission.state = .granted
    for _ in 0..<30 where model.guidedSetupStep == .permission {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(model.guidedSetupStep == .assignments)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(permission.requestCount == 0)
}

@Test("Permission watch stops once switching stops")
@MainActor
func permissionWatchStopsWithSwitching() async throws {
    let permission = SetupModelTestListenPermissionProvider(state: .denied)
    let model = SetupModel(
        permissionProvider: permission,
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    model.activityTriggeredSwitching.start()
    model.activityTriggeredSwitching.stop()
    let countAfterStop = permission.checkCount

    try await Task.sleep(for: .milliseconds(1_200))

    #expect(permission.checkCount == countAfterStop)
}
