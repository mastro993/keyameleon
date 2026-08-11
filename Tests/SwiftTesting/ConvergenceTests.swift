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

    model.refreshPermission()
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

    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 301, kind: .press))
    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 302, kind: .press))
    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 301, kind: .press))

    #expect(selector.selectCount == 3)
    #expect(selector.requestedIdentifiers == [
        "com.example.us",
        "com.example.italian",
        "com.example.us",
    ])
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.wantedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activePhysicalKeyboardID == alphaID)
    #expect(selector.currentInputSourceIdentifier() == "com.example.us")
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

    model.refreshPermission()
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
        model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 322, kind: .press))
    }

    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 321, kind: .press))

    #expect(selector.requestedIdentifiers == ["com.example.us", "com.example.italian"])
    #expect(model.wantedKeyboardAssignmentIdentifier == "com.example.italian")
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.italian")
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

    model.refreshPermission()
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

    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 331, kind: .press))
    #expect(selector.selectCount == 1)

    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 331, kind: .repeat))
    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 331, kind: .press))

    #expect(selector.selectCount == 1)
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
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

    model.refreshPermission()
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

    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 341, kind: .press))
    #expect(selector.selectCount == 1)
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activeInputSourceMismatch == nil)

    // Manual / macOS shortcut / external actor changes Input Source.
    selector.current = "com.example.italian"
    changeObserver.emit()

    #expect(selector.selectCount == 1)
    #expect(model.verifiedKeyboardAssignmentIdentifier == nil)
    #expect(model.observedCurrentInputSourceIdentifier == "com.example.italian")
    #expect(model.activeInputSourceMismatch != nil)
    #expect(model.activeInputSourceMismatch?.currentInputSourceIdentifier == "com.example.italian")
    #expect(model.activeInputSourceMismatch?.assignedInputSourceIdentifier == "com.example.us")

    // Still no fight on another external change.
    selector.current = "com.example.other"
    changeObserver.emit()
    #expect(selector.selectCount == 1)

    // Later assigned Activation Activity restores Keyboard Assignment.
    model.handlePhysicalKeyboardEvent(PhysicalKeyboardEvent(serviceID: 341, kind: .press))
    #expect(selector.selectCount == 2)
    #expect(selector.lastRequestedIdentifier == "com.example.us")
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activeInputSourceMismatch == nil)
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

    model.refreshPermission()
    #expect(changeObserver.startCount == 1)

    permissionProvider.state = .denied
    model.refreshPermission()
    #expect(changeObserver.stopCount == 1)
}

@Test("Serial consumer processes Activation Activity in observation order")
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

    model.refreshPermission()
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

    let events: [(serviceID: UInt64, identifier: String)] = [
        (351, "com.example.us"),
        (352, "com.example.italian"),
        (351, "com.example.us"),
    ]
    for event in events {
        model.handlePhysicalKeyboardEvent(
            PhysicalKeyboardEvent(serviceID: event.serviceID, kind: .press)
        )
    }

    #expect(selector.requestedIdentifiers == events.map { $0.identifier })
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activePhysicalKeyboardID == thetaID)
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
