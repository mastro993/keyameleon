import Testing
@testable import Keyameleon

@MainActor
private func makeConvergeEligibleInputSources() -> SetupModelTestInputSourceProvider {
    SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.italian", name: "Italian"),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
}

@Test("Rapid A-B-A assigned activity converges to newest Keyboard Assignment")
@MainActor
func rapidABAAssignedActivityConvergesToNewestKeyboardAssignment() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: makeConvergeEligibleInputSources(),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 301,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-a"
            )
        )
    )
    let alphaID = model.physicalKeyboards[0].id
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 302,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-b"
            )
        )
    )
    let betaID = model.physicalKeyboards.first { $0.id != alphaID }!.id
    model.setKeyboardAssignment(alphaID, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(betaID, inputSourceIdentifier: "com.example.italian")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 301, kind: .press))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 302, kind: .press))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 301, kind: .press))

    #expect(selector.selectCount == 3)
    #expect(selector.requestedIdentifiers == [
        "com.example.us",
        "com.example.italian",
        "com.example.us",
    ])
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration == 3)
    #expect(model.activePhysicalKeyboardID == alphaID)
    #expect(selector.currentInputSourceIdentifier() == "com.example.us")
}

@Test("Each wanted generation receives one selection request and one readback")
@MainActor
func eachWantedGenerationReceivesOneSelectionRequestAndOneReadback() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: makeConvergeEligibleInputSources(),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 311,
                identity: "macos.keyboard.gamma",
                serialNumber: "serial-g"
            )
        )
    )
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 311, kind: .press))

    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration == 1)
    #expect(selector.selectCount == 1)
    #expect(selector.readbackCount == 1)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
}

@Test("Newer assigned Activation Activity discards stale selection result")
@MainActor
func newerAssignedActivationActivityDiscardsStaleSelectionResult() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: makeConvergeEligibleInputSources(),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 321,
                identity: "macos.keyboard.delta",
                serialNumber: "serial-d"
            )
        )
    )
    let deltaID = model.physicalKeyboards[0].id
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 322,
                identity: "macos.keyboard.epsilon",
                serialNumber: "serial-e"
            )
        )
    )
    let epsilonID = model.physicalKeyboards.first { $0.id != deltaID }!.id
    model.setKeyboardAssignment(deltaID, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(epsilonID, inputSourceIdentifier: "com.example.italian")

    var nested = false
    selector.onSelect = { identifier in
        guard !nested, identifier == "com.example.us" else {
            return
        }
        nested = true
        model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 322, kind: .press))
    }

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 321, kind: .press))

    #expect(selector.requestedIdentifiers == ["com.example.us", "com.example.italian"])
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration == 2)
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentIdentifier == "com.example.italian")
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.italian")
    #expect(model.activePhysicalKeyboardID == epsilonID)
}

@Test("Repeated activity coalesces when wanted Keyboard Assignment already verified")
@MainActor
func repeatedActivityCoalescesWhenWantedKeyboardAssignmentAlreadyVerified() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: makeConvergeEligibleInputSources(),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 331,
                identity: "macos.keyboard.zeta",
                serialNumber: "serial-z"
            )
        )
    )
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 331, kind: .press))
    let generationAfterFirst = model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration
    #expect(selector.selectCount == 1)

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 331, kind: .repeat))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 331, kind: .press))

    #expect(selector.selectCount == 1)
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration == generationAfterFirst)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
}

@Test("External Input Source change stays until later assigned Activation Activity")
@MainActor
func externalInputSourceChangeStaysUntilLaterAssignedActivationActivity() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let changeObserver = SetupModelTestInputSourceChangeObserver()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.italian", name: "Italian"),
            ]
        ),
        inputSourceSelector: selector,
        inputSourceChangeObserver: changeObserver
    )

    startAndCheck(model)
    #expect(changeObserver.startCount == 1)

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 341,
                identity: "macos.keyboard.eta",
                serialNumber: "serial-eta"
            )
        )
    )
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 341, kind: .press))
    #expect(selector.selectCount == 1)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.outcome.mismatch == nil)

    // Manual / macOS shortcut / external actor changes Input Source.
    selector.current = "com.example.italian"
    changeObserver.emit()

    #expect(selector.selectCount == 1)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == nil)
    #expect(model.activityTriggeredSwitching.testingObservedCurrentInputSourceIdentifier == "com.example.italian")
    #expect(model.activityTriggeredSwitching.outcome.mismatch != nil)
    #expect(model.activityTriggeredSwitching.outcome.mismatch?.currentName == "Italian")
    #expect(model.activityTriggeredSwitching.outcome.mismatch?.assignedName == "U.S.")

    // Still no fight on another external change.
    selector.current = "com.example.other"
    changeObserver.emit()
    #expect(selector.selectCount == 1)

    // Later assigned Activation Activity restores Keyboard Assignment.
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 341, kind: .press))
    #expect(selector.selectCount == 2)
    #expect(selector.lastRequestedIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.outcome.mismatch == nil)
}

@Test("Permission Required stops Input Source change observation")
@MainActor
func permissionRequiredStopsInputSourceChangeObservation() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let changeObserver = SetupModelTestInputSourceChangeObserver()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceChangeObserver: changeObserver
    )

    startAndCheck(model)
    #expect(changeObserver.startCount == 1)

    permissionProvider.state = .denied
    startAndCheck(model)
    #expect(changeObserver.stopCount == 1)
}

@Test("Serial consumer processes Activation Activity in observation order under rapid load")
@MainActor
func serialConsumerProcessesActivationActivityInObservationOrderUnderRapidLoad() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: makeConvergeEligibleInputSources(),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 351,
                identity: "macos.keyboard.theta",
                serialNumber: "serial-th"
            )
        )
    )
    let thetaID = model.physicalKeyboards[0].id
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 352,
                identity: "macos.keyboard.iota",
                serialNumber: "serial-io"
            )
        )
    )
    let iotaID = model.physicalKeyboards.first { $0.id != thetaID }!.id
    model.setKeyboardAssignment(thetaID, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(iotaID, inputSourceIdentifier: "com.example.italian")

    var expected: [String] = []
    for index in 0..<200 {
        let useTheta = index % 2 == 0
        expected.append(useTheta ? "com.example.us" : "com.example.italian")
        model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(
                serviceID: useTheta ? 351 : 352,
                kind: .press
            )
        )
    }

    #expect(selector.requestedIdentifiers == expected)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.italian")
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignmentGeneration == 200)
    #expect(model.activePhysicalKeyboardID == iotaID)
}

@MainActor
final class SetupModelTestInputSourceChangeObserver: InputSourceChangeObserving {
    private var onChange: (@MainActor () -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(onChange: @escaping @MainActor () -> Void) {
        startCount += 1
        self.onChange = onChange
    }

    func stop() {
        stopCount += 1
        onChange = nil
    }

    func emit() {
        onChange?()
    }
}
