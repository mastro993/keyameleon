import Testing
@testable import Keyameleon

@Test("Restoring an excluded saved keyboard returns it disconnected with its assignment")
@MainActor
func restoringExcludedSavedKeyboardReturnsItDisconnectedWithItsAssignment() {
    let identityKey = "identity:macos.keyboard.saved|anchor:serial:keyboard-a"
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    recordStore.saveAssignment(
        identityKey: identityKey,
        productName: "Test Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.italian")
    )
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    exclusionStore.exclude(
        SavedPhysicalKeyboardExclusion(
            key: "identity:macos.keyboard.saved",
            name: "Test Keyboard"
        )
    )
    let model = makeOnboardingExclusionModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        recordStore: recordStore,
        exclusionStore: exclusionStore
    )

    #expect(model.physicalKeyboards.isEmpty)
    #expect(model.excludedPhysicalKeyboards.count == 1)

    model.restorePhysicalKeyboard(exclusionKey: "identity:macos.keyboard.saved")

    #expect(model.excludedPhysicalKeyboards.isEmpty)
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.italian")
}

@Test("Restoring an unavailable unsaved keyboard does not create a stale row")
@MainActor
func restoringUnavailableUnsavedKeyboardDoesNotCreateAStaleRow() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOnboardingExclusionModel(discoverer: discoverer)
    startAndCheck(model)
    let facts = PhysicalKeyboardHardwareFacts(
        serviceID: 416,
        identity: nil,
        name: "USB Receiver",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 200,
        productID: 100,
        modelNumber: "Model",
        serialNumber: nil
    )
    discoverer.emit(.connected(facts))
    let keyboardID = try #require(model.physicalKeyboards.first?.id)
    let exclusionKey = try #require(model.exclusionKey(for: keyboardID))

    model.excludePhysicalKeyboard(keyboardID)
    discoverer.emit(.disconnected(serviceID: facts.serviceID))
    model.restorePhysicalKeyboard(exclusionKey: exclusionKey)

    #expect(model.excludedPhysicalKeyboards.isEmpty)
    #expect(model.physicalKeyboards.isEmpty)
}

@Test("Onboarding gets hardware exclusion key for keyboard without identity")
@MainActor
func onboardingGetsHardwareExclusionKeyForKeyboardWithoutIdentity() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOnboardingExclusionModel(discoverer: discoverer)
    startAndCheck(model)
    discoverer.emit(
        .connected(
            PhysicalKeyboardHardwareFacts(
                serviceID: 415,
                identity: nil,
                name: "USB Receiver",
                transport: .usb,
                isBuiltIn: false,
                vendorID: 200,
                productID: 100,
                modelNumber: "Model",
                serialNumber: nil
            )
        )
    )
    let keyboard = try #require(model.physicalKeyboards.first)

    #expect(model.exclusionKey(for: keyboard.id) == "hardware:200:100:Model")
}

@MainActor
private func makeOnboardingExclusionModel(
    discoverer: SetupModelTestPhysicalKeyboardDiscoverer,
    recordStore: InMemoryPhysicalKeyboardRecordStore = InMemoryPhysicalKeyboardRecordStore(),
    exclusionStore: InMemoryPhysicalKeyboardExclusionStore = InMemoryPhysicalKeyboardExclusionStore()
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore,
        exclusionStore: exclusionStore
    )
}
