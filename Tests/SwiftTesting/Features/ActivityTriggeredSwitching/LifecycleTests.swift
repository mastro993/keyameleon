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

@Test("Disconnected saved Physical Keyboard stays listed")
@MainActor
func disconnectedSavedPhysicalKeyboardStaysListed() {
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
    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue)?.customName == "Studio")
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

@Test("Saved name and assignment stay with a Physical Keyboard across connection states")
@MainActor
func savedNameAndAssignmentStayAcrossConnectionStates() {
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

@Test("Physical Keyboard list ignores active state when sorting")
@MainActor
func physicalKeyboardListSortIgnoresActiveState() {
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

    #expect(model.physicalKeyboards.map(\.name) == ["Alpha", "Zeta", "Delta"])
    #expect(model.physicalKeyboards.map(\.isActive) == [false, true, false])
    #expect(
        model.physicalKeyboards.map(\.connectionState)
            == [.connected, .connected, .disconnected]
    )
}
