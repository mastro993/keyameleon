import Foundation
import Testing
@testable import Keyameleon

@Test("Completing setup notifies once")
@MainActor
func completingSetupNotifiesOnce() {
    var completionCount = 0
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    model.onGuidedSetupCompleted = { _ in
        completionCount += 1
    }

    model.beginGuidedSetup()
    model.continueToReady()
    model.completeSetup(destination: .menuBar)
    model.completeSetup(destination: .settings)

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
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
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

@Test("Ready persists across a real UserDefaults store and completed state takes precedence")
@MainActor
func readyPersistsAcrossUserDefaultsStore() throws {
    let name = "KeyameleonSetupTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let firstStore = UserDefaultsSetupDecisionStore(defaults: defaults)
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: firstStore,
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    model.beginGuidedSetup()
    model.continueToReady()
    #expect(UserDefaultsSetupDecisionStore(defaults: defaults).guidedSetupStep == .ready)

    let resumed = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .denied),
        setupStore: UserDefaultsSetupDecisionStore(defaults: defaults),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    resumed.beginGuidedSetup()
    #expect(resumed.guidedSetupStep == .ready)
    #expect(!resumed.isSetupComplete)
    resumed.completeSetup(destination: .menuBar)
    defaults.set(GuidedSetupStep.permission.rawValue, forKey: "keyameleon.guidedSetup.step")
    let historical = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .denied),
        setupStore: UserDefaultsSetupDecisionStore(defaults: defaults),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    #expect(historical.isSetupComplete)
    #expect(historical.guidedSetupStep == .ready)
}

@Test("Back retains saved Keyboard Assignment and completion destination is delivered once")
@MainActor
func readyBackKeepsAssignmentsAndCompletesOnce() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S.")
        ]),
        physicalKeyboardRecordStore: recordStore
    )
    startAndCheck(model)
    model.beginGuidedSetup()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 50)))
    guard let keyboard = model.physicalKeyboards.first else {
        Issue.record("Missing discovered keyboard")
        return
    }
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.us")
    model.continueToReady()
    model.returnToAssignments()
    #expect(model.physicalKeyboards.first?.keyboardAssignment?.inputSourceIdentifier == "com.example.us")
    model.continueToReady()
    var destinations: [GuidedSetupCompletionDestination] = []
    model.onGuidedSetupCompleted = { destinations.append($0) }
    model.completeSetup(destination: .settings)
    model.completeSetup(destination: .menuBar)
    #expect(destinations == [.settings])
    #expect(model.isSetupComplete)
}
