import Foundation
import SwiftData
import Testing
@testable import Keyameleon

@Test("Reopening an excluded assigned keyboard retains its saved Input Source")
@MainActor
func reopeningExcludedAssignedKeyboardRetainsItsSource() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOnboardingExclusionModel(
        discoverer: discoverer, recordStore: recordStore, exclusionStore: exclusionStore
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 600)))
    let keyboard = try #require(model.physicalKeyboards.first)
    let exclusionKey = try #require(model.exclusionKey(for: keyboard.id))
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.german")
    model.excludePhysicalKeyboard(keyboard.id)

    let reopened = makeOnboardingExclusionModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        recordStore: recordStore,
        exclusionStore: exclusionStore
    )
    startAndCheck(reopened)
    #expect(reopened.physicalKeyboards.isEmpty)
    let saved = try #require(reopened.savedPhysicalKeyboardRecords.first)
    #expect(saved.keyboardAssignment?.inputSourceIdentifier == "com.example.german")
    let rows = OnboardingPhysicalKeyboardRows(
        physicalKeyboards: reopened.physicalKeyboards,
        exclusions: reopened.excludedPhysicalKeyboards,
        savedRecords: reopened.savedPhysicalKeyboardRecords,
        exclusionKeyFor: reopened.exclusionKey(for:)
    )
    #expect(rows.rows.first?.state == .excluded(
        SavedPhysicalKeyboardExclusion(key: exclusionKey, name: keyboard.name), .matched(saved)
    ))

    reopened.restorePhysicalKeyboard(exclusionKey: exclusionKey)
    #expect(reopened.physicalKeyboards.first?.keyboardAssignment?.inputSourceIdentifier
        == "com.example.german")
}

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

@Test("Renaming a hidden keyboard preserves its exclusion and assignment through unhide")
@MainActor
func renamingHiddenKeyboardPreservesExclusionAndAssignment() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOnboardingExclusionModel(
        discoverer: discoverer, recordStore: recordStore, exclusionStore: exclusionStore
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 601)))
    let keyboard = try #require(model.physicalKeyboards.first)
    let exclusionKey = try #require(model.exclusionKey(for: keyboard.id))
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.german")
    model.excludePhysicalKeyboard(keyboard.id)

    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel")

    let hidden = try #require(model.savedPhysicalKeyboardRecords.first)
    #expect(hidden.name == "Travel")
    #expect(hidden.keyboardAssignment?.inputSourceIdentifier == "com.example.german")
    #expect(model.excludedPhysicalKeyboards.map(\.key) == [exclusionKey])
    #expect(model.physicalKeyboards.isEmpty)

    model.restorePhysicalKeyboard(exclusionKey: exclusionKey)
    let restored = try #require(model.physicalKeyboards.first)
    #expect(restored.name == "Travel")
    #expect(restored.keyboardAssignment?.inputSourceIdentifier == "com.example.german")
}

@Test("Hidden rename refuses an excluded identity with no exact saved record")
@MainActor
func hiddenRenameDoesNotRecreateMissingRecord() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    exclusionStore.exclude(SavedPhysicalKeyboardExclusion(
        key: "identity:macos.keyboard.missing", name: "Missing Keyboard"
    ))
    let model = makeOnboardingExclusionModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        recordStore: recordStore,
        exclusionStore: exclusionStore
    )

    model.setPhysicalKeyboardName(
        PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.missing|anchor:serial:missing"),
        customName: "Ghost"
    )

    #expect(model.savedPhysicalKeyboardRecords.isEmpty)
    #expect(recordStore.allRecords().isEmpty)
    #expect(model.excludedPhysicalKeyboards.count == 1)
}

@Test("Hidden rename requires an active exclusion for a saved record")
@MainActor
func hiddenRenameRequiresCurrentExclusion() {
    let identityKey = "identity:macos.keyboard.saved|anchor:serial:keyboard-a"
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    recordStore.saveName(identityKey: identityKey, productName: "Test Keyboard", customName: "Old")
    let model = makeOnboardingExclusionModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(), recordStore: recordStore
    )

    model.setPhysicalKeyboardName(PhysicalKeyboardRecordID(rawValue: identityKey), customName: "New")

    #expect(recordStore.record(forIdentityKey: identityKey)?.name == "Old")
}

@Test("A failed hidden rename preserves visible state and retries the original name")
@MainActor
func failedHiddenRenamePreservesStateUntilRetry() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), save: {
        if fails { throw CocoaError(.fileWriteUnknown) }
        try $0.save()
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: records,
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 602)))
    let keyboard = try #require(model.physicalKeyboards.first)
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.german")
    model.excludePhysicalKeyboard(keyboard.id)
    let saved = try #require(model.savedPhysicalKeyboardRecords.first)
    let exclusions = model.excludedPhysicalKeyboards

    fails = true
    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel")
    let failure = try #require(model.persistenceError)
    #expect(model.savedPhysicalKeyboardRecords == [saved])
    model.setPhysicalKeyboardName(keyboard.id, customName: "Must not replace pending rename")
    #expect(model.persistenceError == failure)
    #expect(model.excludedPhysicalKeyboards == exclusions)

    fails = false
    model.retryPersistenceOperation()
    let renamed = try #require(model.savedPhysicalKeyboardRecords.first)
    #expect(model.persistenceError == nil)
    #expect(renamed.name == "Travel")
    #expect(renamed.keyboardAssignment == saved.keyboardAssignment)
    #expect(model.excludedPhysicalKeyboards == exclusions)
    #expect(model.physicalKeyboards.isEmpty)
}
