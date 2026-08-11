import Testing
@testable import Keyameleon

@Test("Physical Keyboard discovery records identity-based connection lifecycle")
@MainActor
func physicalKeyboardDiscoveryRecordsIdentityBasedConnectionLifecycle() {
    let diagnostic = KeyameleonDiagnosticDataService(store: InMemoryDiagnosticDataStore())
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        diagnosticDataController: diagnostic
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 100)))
    discoverer.emit(.disconnected(serviceID: 100))

    #expect(
        diagnostic.allRecords().map(\.code)
            == [.physicalKeyboardConnected, .physicalKeyboardDisconnected]
    )
}

@Test("Activation Activity sets Active Physical Keyboard")
@MainActor
func activationActivitySetsActivePhysicalKeyboard() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 101)))

    #expect(model.activePhysicalKeyboardID == nil)
    #expect(eventObserver.startCount == 1)

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 101, kind: .press)
    )

    #expect(model.activePhysicalKeyboardID == model.physicalKeyboards[0].id)
    #expect(model.activePhysicalKeyboard?.name == "Test Keyboard")
}

@Test("Release-only Physical Keyboard Event is not Activation Activity")
@MainActor
func releaseOnlyPhysicalKeyboardEventIsNotActivationActivity() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 102)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 102, kind: .release)
    )

    #expect(model.activePhysicalKeyboardID == nil)
    #expect(selector.selectCount == 0)
}

@Test("Assigned Activation Activity requests exact Keyboard Assignment and verifies readback")
@MainActor
func assignedActivationActivityRequestsExactKeyboardAssignmentAndVerifiesReadback() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.italian", name: "Italian"),
                EligibleInputSource(identifier: "com.example.other", name: "Other"),
            ]
        ),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 103)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.italian")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 103, kind: .press)
    )

    #expect(selector.selectCount == 1)
    #expect(selector.lastRequestedIdentifier == "com.example.italian")
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.italian")
    #expect(model.activePhysicalKeyboardID == keyboardID)
}

@Test("Unassigned and unsupported Activation Activity does not request Input Source change")
@MainActor
func unassignedAndUnsupportedActivationActivityDoesNotRequestInputSourceChange() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 104)))
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 105,
                identity: "macos.keyboard.unstable",
                serialNumber: nil
            )
        )
    )

    // Unassigned stable keyboard
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 104, kind: .press)
    )
    #expect(model.activePhysicalKeyboardID != nil)
    #expect(selector.selectCount == 0)

    // Unsupported unstable identity
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 105, kind: .repeat)
    )
    #expect(selector.selectCount == 0)
}

@Test("Verified assignment coalesces further Activation Activity without reselect")
@MainActor
func verifiedAssignmentCoalescesFurtherActivationActivityWithoutReselect() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S.")
            ]
        ),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 106)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 106, kind: .press)
    )
    #expect(selector.selectCount == 1)

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 106, kind: .repeat)
    )
    #expect(selector.selectCount == 1)
}

@Test("Failed verification leaves Active Physical Keyboard and does not mark assignment verified")
@MainActor
func failedVerificationLeavesActivePhysicalKeyboardAndDoesNotMarkAssignmentVerified() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.other", name: "Other"),
            ]
        ),
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 107)))
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 107, kind: .press)
    )

    #expect(selector.selectCount == 1)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == nil)
    #expect(model.activePhysicalKeyboardID == model.physicalKeyboards[0].id)
    // Failed select must not rewrite the observed current Input Source in the fake.
    #expect(selector.currentInputSourceIdentifier() == "com.example.other")
}

@Test("Active Physical Keyboard sorts first in Guided setup list")
@MainActor
func activePhysicalKeyboardSortsFirstInGuidedSetupList() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 108,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-a"
            )
        )
    )
    let alphaID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(alphaID, customName: "Alpha")

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 109,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-b"
            )
        )
    )
    let betaID = model.physicalKeyboards.first { $0.id != alphaID }!.id
    model.setPhysicalKeyboardName(betaID, customName: "Beta")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 109, kind: .press)
    )

    #expect(model.physicalKeyboards[0].id == betaID)
    #expect(model.physicalKeyboards[0].name == "Beta")
}

@Test("Permission Required stops Physical Keyboard Event observation")
@MainActor
func permissionRequiredStopsPhysicalKeyboardEventObservation() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    #expect(eventObserver.startCount == 1)

    permissionProvider.state = .denied
    startAndCheck(model)
    #expect(eventObserver.stopCount == 1)
}

@Test("Switching outcome does not expose an unknown Input Source identifier")
@MainActor
func switchingOutcomeDoesNotExposeUnknownInputSourceIdentifier() {
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.known", name: "Known")
            ]
        ),
        inputSourceSelector: SetupModelTestInputSourceSelector(
            current: "com.example.unknown"
        )
    )

    startAndCheck(model)

    #expect(model.activityTriggeredSwitching.outcome.currentInputSourceName == nil)
}

@Test("Catalog resolves Physical Keyboard by service ID for attribution")
func catalogResolvesPhysicalKeyboardByServiceIDForAttribution() {
    var catalog = PhysicalKeyboardCatalog()
    catalog.apply(.connected(makeSetupModelHardwareFacts(serviceID: 201)))
    catalog.apply(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 202,
                identity: "macos.keyboard.shared",
                serialNumber: "keyboard-a"
            )
        )
    )

    let first = catalog.physicalKeyboard(forServiceID: 201)
    let second = catalog.physicalKeyboard(forServiceID: 202)
    #expect(first != nil)
    #expect(second != nil)
    #expect(first?.id == second?.id)
    #expect(catalog.physicalKeyboard(forServiceID: 999) == nil)
}

@MainActor
final class SetupModelTestInputSourceSelector: InputSourceSelecting {
    var current: String?
    var verifySuccess: Bool
    var onSelect: ((String) -> Void)?
    private(set) var selectCount = 0
    private(set) var readbackCount = 0
    private(set) var lastRequestedIdentifier: String?
    private(set) var requestedIdentifiers: [String] = []

    init(current: String? = nil, verifySuccess: Bool = true) {
        self.current = current
        self.verifySuccess = verifySuccess
    }

    func currentInputSourceIdentifier() -> String? {
        current
    }

    func selectAndVerifyInputSource(identifier: String) -> Bool {
        selectCount += 1
        lastRequestedIdentifier = identifier
        requestedIdentifiers.append(identifier)
        onSelect?(identifier)
        // Exact-identifier readback after selection request.
        readbackCount += 1
        guard verifySuccess else {
            return false
        }

        current = identifier
        return true
    }
}

@MainActor
final class SetupModelTestPhysicalKeyboardEventObserver: PhysicalKeyboardEventObserving {
    private var onEvent: (@MainActor (PhysicalKeyboardEvent) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(onEvent: @escaping @MainActor (PhysicalKeyboardEvent) -> Void) {
        startCount += 1
        self.onEvent = onEvent
    }

    func stop() {
        stopCount += 1
        onEvent = nil
    }

    func emit(_ event: PhysicalKeyboardEvent) {
        onEvent?(event)
    }
}
