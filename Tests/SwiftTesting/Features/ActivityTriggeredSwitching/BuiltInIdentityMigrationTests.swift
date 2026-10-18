import Testing
@testable import Keyameleon

@Test("Built-in Physical Keyboard migrates one old saved record")
@MainActor
func builtInPhysicalKeyboardMigratesOneOldSavedRecord() {
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

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer
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

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer
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
