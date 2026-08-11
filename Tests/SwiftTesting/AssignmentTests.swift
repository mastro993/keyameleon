import Testing
@testable import Keyameleon

@Test("Physical Keyboard Name defaults to product name and accepts custom value")
@MainActor
func physicalKeyboardNameDefaultsToProductNameAndAcceptsCustomValue() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 51)))

    #expect(model.physicalKeyboards[0].name == "Test Keyboard")
    #expect(model.physicalKeyboards[0].customName == nil)

    model.setPhysicalKeyboardName(model.physicalKeyboards[0].id, customName: "Travel")

    #expect(model.physicalKeyboards[0].name == "Travel")
    #expect(
        recordStore.record(forIdentityKey: model.physicalKeyboards[0].id.rawValue)?.customName
            == "Travel"
    )
}

@Test("Duplicate Physical Keyboard Names stay valid and leave identity unchanged")
@MainActor
func duplicatePhysicalKeyboardNamesStayValidAndLeaveIdentityUnchanged() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 52,
                identity: "macos.keyboard.one",
                serialNumber: "serial-one"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 53,
                identity: "macos.keyboard.two",
                serialNumber: "serial-two"
            )
        )
    )

    let firstID = model.physicalKeyboards[0].id
    let secondID = model.physicalKeyboards[1].id
    model.setPhysicalKeyboardName(firstID, customName: "Same Name")
    model.setPhysicalKeyboardName(secondID, customName: "Same Name")

    #expect(model.physicalKeyboards.map(\.name) == ["Same Name", "Same Name"])
    #expect(firstID != secondID)
    #expect(model.physicalKeyboards[0].id == firstID)
    #expect(model.physicalKeyboards[1].id == secondID)
}

@Test("Keyboard Assignment saves exact Input Source identifier immediately without selection request")
@MainActor
func keyboardAssignmentSavesExactInputSourceIdentifierImmediatelyWithoutSelectionRequest() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.italian", name: "Italian"),
                EligibleInputSource(identifier: "com.example.us", name: "U.S.")
            ]
        ),
        physicalKeyboardRecordStore: recordStore
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 54)))

    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.italian")

    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier
            == "com.example.italian"
    )
    #expect(model.assignmentDisplayName(for: model.physicalKeyboards[0]) == "Italian")
    #expect(
        recordStore.record(forIdentityKey: keyboardID.rawValue)?
            .keyboardAssignment?.inputSourceIdentifier == "com.example.italian"
    )
}

@Test("Searchable assignment picker filters by Input Source name only")
@MainActor
func searchableAssignmentPickerFiltersByInputSourceNameOnly() {
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.apple.keylayout.Italian", name: "Italian"),
                EligibleInputSource(identifier: "com.apple.keylayout.US", name: "U.S."),
                EligibleInputSource(identifier: "com.apple.keylayout.British", name: "British")
            ]
        )
    )

    startAndCheck(model)

    let filtered = model.filteredInputSources(matching: "ita")
    #expect(filtered.map(\.name) == ["Italian"])
    #expect(filtered.allSatisfy { !$0.name.contains("com.apple") })
}

@Test("SwiftData store keeps names and assignments across containers")
@MainActor
func swiftDataStoreKeepsNamesAndAssignmentsAcrossContainers() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    let firstStore = SwiftDataPhysicalKeyboardRecordStore(
        modelContext: .init(container)
    )
    let identityKey = "identity:macos.keyboard.shared|anchor:serial:keyboard-a"

    firstStore.saveName(
        identityKey: identityKey,
        productName: "Test Keyboard",
        customName: "Studio"
    )
    firstStore.saveAssignment(
        identityKey: identityKey,
        productName: "Test Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )

    let secondStore = SwiftDataPhysicalKeyboardRecordStore(
        modelContext: .init(container)
    )
    let saved = secondStore.record(forIdentityKey: identityKey)

    #expect(saved?.displayName == "Studio")
    #expect(saved?.keyboardAssignment?.inputSourceIdentifier == "com.example.us")
}
