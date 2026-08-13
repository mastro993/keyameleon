import Testing
@testable import Keyameleon

@Test("Same Physical Keyboard Identity keeps name and assignment across disconnect and reconnect")
@MainActor
func samePhysicalKeyboardIdentityKeepsNameAndAssignmentAcrossDisconnectAndReconnect() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 101)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(keyboardID, customName: "Travel")
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    discoverer.emit(.disconnected(serviceID: 101))
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(model.physicalKeyboards[0].name == "Travel")
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.us"
    )

    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 102)))
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .connected)
    #expect(model.physicalKeyboards[0].id == keyboardID)
    #expect(model.physicalKeyboards[0].name == "Travel")
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.us"
    )
}

@Test("Disconnected saved Physical Keyboard remains until forgotten")
@MainActor
func disconnectedSavedPhysicalKeyboardRemainsUntilForgotten() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 111)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(keyboardID, customName: "Studio")
    discoverer.emit(.disconnected(serviceID: 111))

    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)

    model.forgetPhysicalKeyboard(keyboardID)

    #expect(model.physicalKeyboards.isEmpty)
    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue) == nil)
}

@Test("Disconnected Active Physical Keyboard stays active with no Input Source request")
@MainActor
func disconnectedActivePhysicalKeyboardStaysActiveWithNoInputSourceRequest() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector()
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        selector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 121)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    model.activityTriggeredSwitching.markActiveForTesting(keyboardID)

    #expect(model.activePhysicalKeyboardID == keyboardID)
    #expect(selector.selectCount == 0)

    discoverer.emit(.disconnected(serviceID: 121))

    #expect(model.activePhysicalKeyboardID == keyboardID)
    #expect(model.physicalKeyboards[0].isActive)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(selector.selectCount == 0)
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 0)
}

@Test("Unsaved Active Physical Keyboard still appears disconnected after disconnect")
@MainActor
func unsavedActivePhysicalKeyboardStillAppearsDisconnectedAfterDisconnect() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 122)))
    let keyboardID = model.physicalKeyboards[0].id
    model.activityTriggeredSwitching.markActiveForTesting(keyboardID)
    discoverer.emit(.disconnected(serviceID: 122))

    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].id == keyboardID)
    #expect(model.physicalKeyboards[0].isActive)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(model.physicalKeyboards[0].assignmentState == .unassigned)
}

@Test("Changed Physical Keyboard Identity creates new unassigned record and keeps old disconnected")
@MainActor
func changedPhysicalKeyboardIdentityCreatesNewUnassignedAndKeepsOldDisconnected() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 131,
                identity: "macos.keyboard.old",
                serialNumber: "serial-old"
            )
        )
    )
    let oldID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(oldID, customName: "Old Board")
    model.setKeyboardAssignment(oldID, inputSourceIdentifier: "com.example.us")
    discoverer.emit(.disconnected(serviceID: 131))

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 132,
                identity: "macos.keyboard.new",
                serialNumber: "serial-new"
            )
        )
    )

    #expect(model.physicalKeyboards.count == 2)
    let connected = model.physicalKeyboards.first { $0.connectionState == .connected }
    let disconnected = model.physicalKeyboards.first { $0.connectionState == .disconnected }
    #expect(connected?.id != oldID)
    #expect(connected?.assignmentState == .unassigned)
    #expect(connected?.customName == nil)
    #expect(disconnected?.id == oldID)
    #expect(disconnected?.name == "Old Board")
    #expect(disconnected?.keyboardAssignment?.inputSourceIdentifier == "com.example.us")
}

@Test("Replace candidates list only disconnected saved records")
@MainActor
func replaceCandidatesListOnlyDisconnectedSavedRecords() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 141,
                identity: "macos.keyboard.saved",
                serialNumber: "serial-saved"
            )
        )
    )
    let savedID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(savedID, customName: "Saved Board")
    discoverer.emit(.disconnected(serviceID: 141))

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 142,
                identity: "macos.keyboard.live",
                serialNumber: "serial-live"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 143,
                identity: "macos.keyboard.other-live",
                serialNumber: "serial-other-live"
            )
        )
    )
    let liveID = model.physicalKeyboards.first {
        $0.connectionState == .connected && $0.id.rawValue.contains("live")
    }!.id

    let candidates = model.replaceCandidates(for: liveID)
    #expect(candidates.map(\.id) == [savedID])
    #expect(candidates.allSatisfy { $0.connectionState == .disconnected })
}

@Test("Replacement moves name and assignment then removes old record")
@MainActor
func replacementMovesNameAndAssignmentThenRemovesOldRecord() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 151,
                identity: "macos.keyboard.old",
                serialNumber: "serial-old"
            )
        )
    )
    let oldID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(oldID, customName: "Desk")
    model.setKeyboardAssignment(oldID, inputSourceIdentifier: "com.example.italian")
    discoverer.emit(.disconnected(serviceID: 151))

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 152,
                identity: "macos.keyboard.new",
                serialNumber: "serial-new"
            )
        )
    )
    let newID = model.physicalKeyboards.first { $0.connectionState == .connected }!.id

    model.replaceSavedPhysicalKeyboard(oldID, with: newID)

    #expect(recordStore.record(forIdentityKey: oldID.rawValue) == nil)
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].id == newID)
    #expect(model.physicalKeyboards[0].name == "Desk")
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier
            == "com.example.italian"
    )

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 153,
                identity: "macos.keyboard.old",
                serialNumber: "serial-old"
            )
        )
    )
    let returned = model.physicalKeyboards.first { $0.id == oldID }
    #expect(returned?.assignmentState == .unassigned)
    #expect(returned?.customName == nil)
}

@Test("Forget candidates expose saved name and connection state")
@MainActor
func forgetCandidatesExposeSavedNameAndConnectionState() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 161)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(keyboardID, customName: "Travel")
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    let connectedKeyboard = model.physicalKeyboards.first { $0.id == keyboardID }
    #expect(connectedKeyboard?.name == "Travel")
    #expect(connectedKeyboard?.connectionState == .connected)
    #expect(connectedKeyboard?.keyboardAssignment?.inputSourceIdentifier == "com.example.us")

    discoverer.emit(.disconnected(serviceID: 161))
    let disconnectedKeyboard = model.physicalKeyboards.first { $0.id == keyboardID }
    #expect(disconnectedKeyboard?.name == "Travel")
    #expect(disconnectedKeyboard?.connectionState == .disconnected)
}

@Test("Built-in Physical Keyboard migrates one old saved record and linked Diagnostic Data")
@MainActor
func builtInPhysicalKeyboardMigratesOneOldSavedRecordAndLinkedDiagnosticData() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let oldIdentityKey = "identity:legacy-built-in|anchor:built-in"
    recordStore.saveName(
        identityKey: oldIdentityKey,
        productName: "Legacy Internal Keyboard",
        customName: "Laptop"
    )
    recordStore.saveAssignment(
        identityKey: oldIdentityKey,
        productName: "Legacy Internal Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )

    let diagnostic = KeyameleonDiagnosticDataService(store: InMemoryDiagnosticDataStore())
    diagnostic.record(
        code: .assignmentSaved,
        identityKey: oldIdentityKey,
        switchingStatus: nil
    )

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        diagnostic: diagnostic
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeBuiltInLifecycleHardwareFacts(
                serviceID: 171,
                identity: "macos.keyboard.changed"
            )
        )
    )

    let builtIn = model.physicalKeyboards.first { $0.isBuiltIn }
    #expect(builtIn?.id.rawValue == "identity:built-in|anchor:built-in")
    #expect(builtIn?.name == "Laptop")
    #expect(builtIn?.keyboardAssignment?.inputSourceIdentifier == "com.example.us")
    #expect(recordStore.record(forIdentityKey: oldIdentityKey) == nil)
    #expect(
        recordStore.record(forIdentityKey: "identity:built-in|anchor:built-in")?.customName
            == "Laptop"
    )
    #expect(diagnostic.allRecords().isEmpty)
}

@Test("Built-in Physical Keyboard does not migrate when multiple old records exist")
@MainActor
func builtInPhysicalKeyboardDoesNotMigrateWhenMultipleOldRecordsExist() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let firstOldIdentityKey = "identity:legacy-built-in-one|anchor:built-in"
    let secondOldIdentityKey = "identity:legacy-built-in-two|anchor:built-in"
    recordStore.saveName(
        identityKey: firstOldIdentityKey,
        productName: "Legacy Internal Keyboard",
        customName: "Laptop"
    )
    recordStore.saveAssignment(
        identityKey: secondOldIdentityKey,
        productName: "Legacy Internal Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )

    let diagnostic = KeyameleonDiagnosticDataService(store: InMemoryDiagnosticDataStore())
    diagnostic.record(
        code: .assignmentSaved,
        identityKey: firstOldIdentityKey,
        switchingStatus: nil
    )
    diagnostic.record(
        code: .assignmentSaved,
        identityKey: secondOldIdentityKey,
        switchingStatus: nil
    )

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        diagnostic: diagnostic
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeBuiltInLifecycleHardwareFacts(
                serviceID: 172,
                identity: nil,
                name: "Built-in Keyboard"
            )
        )
    )

    let builtIn = model.physicalKeyboards.first { $0.isBuiltIn }
    #expect(builtIn?.id.rawValue == "identity:built-in|anchor:built-in")
    #expect(builtIn?.assignmentState == .unassigned)
    #expect(builtIn?.customName == nil)
    #expect(recordStore.record(forIdentityKey: firstOldIdentityKey) != nil)
    #expect(recordStore.record(forIdentityKey: secondOldIdentityKey) != nil)
    #expect(recordStore.record(forIdentityKey: "identity:built-in|anchor:built-in") == nil)
    #expect(diagnostic.allRecords().count == 2)
}

@Test("Built-in Physical Keyboard migration is evaluated only once across restarts")
@MainActor
func builtInPhysicalKeyboardMigrationIsEvaluatedOnlyOnceAcrossRestarts() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let firstOldIdentityKey = "identity:legacy-built-in-one|anchor:built-in"
    let secondOldIdentityKey = "identity:legacy-built-in-two|anchor:built-in"
    recordStore.saveName(
        identityKey: firstOldIdentityKey,
        productName: "Legacy Internal Keyboard",
        customName: "First"
    )
    recordStore.saveName(
        identityKey: secondOldIdentityKey,
        productName: "Legacy Internal Keyboard",
        customName: "Second"
    )

    let setupStore = SetupModelTestSetupDecisionStore()
    let firstDiscoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let firstModel = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: firstDiscoverer,
        setupStore: setupStore
    )
    startAndCheck(firstModel)
    firstDiscoverer.emit(
        .connected(
            makeBuiltInLifecycleHardwareFacts(serviceID: 173, identity: nil)
        )
    )

    recordStore.deleteRecord(identityKey: firstOldIdentityKey)

    let secondDiscoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let secondModel = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: secondDiscoverer,
        setupStore: setupStore
    )
    startAndCheck(secondModel)
    secondDiscoverer.emit(
        .connected(
            makeBuiltInLifecycleHardwareFacts(serviceID: 174, identity: nil)
        )
    )

    let builtIn = secondModel.physicalKeyboards.first { $0.isBuiltIn }
    #expect(builtIn?.assignmentState == .unassigned)
    #expect(builtIn?.customName == nil)
    #expect(recordStore.record(forIdentityKey: secondOldIdentityKey)?.customName == "Second")
    #expect(recordStore.record(forIdentityKey: PhysicalKeyboardRecordID.builtIn.rawValue) == nil)
}

private func makeBuiltInLifecycleHardwareFacts(
    serviceID: UInt64,
    identity: String?,
    name: String? = "Apple Internal Keyboard"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: identity.flatMap {
            PhysicalKeyboardIdentity(rawValue: $0, isBuiltIn: true, serialNumber: nil)
        },
        name: name,
        transport: .usb,
        isBuiltIn: true,
        vendorID: 500,
        productID: 100,
        modelNumber: "Model",
        serialNumber: nil
    )
}

@Test("Connected forgotten Physical Keyboard reappears unassigned; disconnected disappears")
@MainActor
func forgetConnectedReappearsUnassignedAndDisconnectedDisappears() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 171,
                identity: "macos.keyboard.one",
                serialNumber: "serial-one"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 172,
                identity: "macos.keyboard.two",
                serialNumber: "serial-two"
            )
        )
    )

    let firstID = model.physicalKeyboards.first {
        $0.id.rawValue.contains("one")
    }!.id
    let secondID = model.physicalKeyboards.first {
        $0.id.rawValue.contains("two")
    }!.id

    model.setPhysicalKeyboardName(firstID, customName: "Alpha")
    model.setKeyboardAssignment(firstID, inputSourceIdentifier: "com.example.us")
    model.setPhysicalKeyboardName(secondID, customName: "Beta")
    model.setKeyboardAssignment(secondID, inputSourceIdentifier: "com.example.italian")

    discoverer.emit(.disconnected(serviceID: 172))
    model.forgetPhysicalKeyboard(firstID)
    model.forgetPhysicalKeyboard(secondID)

    let connectedForgotten = model.physicalKeyboards.first { $0.id == firstID }
    #expect(connectedForgotten != nil)
    #expect(connectedForgotten?.connectionState == .connected)
    #expect(connectedForgotten?.assignmentState == .unassigned)
    #expect(connectedForgotten?.customName == nil)
    #expect(model.physicalKeyboards.contains { $0.id == secondID } == false)
    #expect(recordStore.record(forIdentityKey: firstID.rawValue) == nil)
    #expect(recordStore.record(forIdentityKey: secondID.rawValue) == nil)
}

@Test("Physical Keyboard list sorts active, connected, then disconnected by name")
@MainActor
func physicalKeyboardListSortsActiveConnectedThenDisconnectedByName() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 181,
                identity: "macos.keyboard.zeta",
                serialNumber: "serial-zeta"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 182,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-alpha"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 183,
                identity: "macos.keyboard.delta",
                serialNumber: "serial-delta"
            )
        )
    )

    let zetaID = model.physicalKeyboards.first { $0.id.rawValue.contains("zeta") }!.id
    let alphaID = model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }!.id
    let deltaID = model.physicalKeyboards.first { $0.id.rawValue.contains("delta") }!.id

    model.setPhysicalKeyboardName(zetaID, customName: "Zeta")
    model.setPhysicalKeyboardName(alphaID, customName: "Alpha")
    model.setPhysicalKeyboardName(deltaID, customName: "Delta")
    discoverer.emit(.disconnected(serviceID: 183))
    model.activityTriggeredSwitching.markActiveForTesting(zetaID)

    #expect(model.physicalKeyboards.map(\.name) == ["Zeta", "Alpha", "Delta"])
    #expect(model.physicalKeyboards.map(\.isActive) == [true, false, false])
    #expect(
        model.physicalKeyboards.map(\.connectionState)
            == [.connected, .connected, .disconnected]
    )
}

@MainActor
private func makeLifecycleModel(
    recordStore: InMemoryPhysicalKeyboardRecordStore,
    discoverer: SetupModelTestPhysicalKeyboardDiscoverer,
    selector: SetupModelTestInputSourceSelector = SetupModelTestInputSourceSelector(),
    setupStore: any SetupDecisionStoring = SetupModelTestSetupDecisionStore(),
    diagnostic: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore()
    )
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.italian", name: "Italian")
            ]
        ),
        inputSourceSelector: selector,
        physicalKeyboardRecordStore: recordStore,
        diagnosticDataController: diagnostic
    )
}
