import Testing
@testable import Keyameleon

@Test("Same Physical Keyboard Identity keeps name and assignment across disconnect and reconnect")
@MainActor
func samePhysicalKeyboardIdentityKeepsNameAndAssignmentAcrossDisconnectAndReconnect() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    model.refreshPermission()
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

    model.refreshPermission()
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
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 121)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    model.noteActivationActivity(for: keyboardID)

    #expect(model.activePhysicalKeyboardID == keyboardID)

    discoverer.emit(.disconnected(serviceID: 121))

    #expect(model.activePhysicalKeyboardID == keyboardID)
    #expect(model.physicalKeyboards[0].isActive)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
}

@Test("Unsaved Active Physical Keyboard still appears disconnected after disconnect")
@MainActor
func unsavedActivePhysicalKeyboardStillAppearsDisconnectedAfterDisconnect() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 122)))
    let keyboardID = model.physicalKeyboards[0].id
    model.noteActivationActivity(for: keyboardID)
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

    model.refreshPermission()
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

    model.refreshPermission()
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

    model.refreshPermission()
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

    model.refreshPermission()
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

@Test("Connected forgotten Physical Keyboard reappears unassigned; disconnected disappears")
@MainActor
func forgetConnectedReappearsUnassignedAndDisconnectedDisappears() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(recordStore: recordStore, discoverer: discoverer)

    model.refreshPermission()
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

    model.refreshPermission()
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
    model.noteActivationActivity(for: zetaID)

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
    discoverer: SetupModelTestPhysicalKeyboardDiscoverer
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.italian", name: "Italian")
            ]
        ),
        physicalKeyboardRecordStore: recordStore
    )
}
