import Foundation
import SwiftData
import Testing
@testable import Keyameleon

private enum PersistenceInjectedFailure: Error {
    case unavailable
}

private enum FailedRecordEdit: CaseIterable {
    case rename, assignment, delete, transfer, insert

    @MainActor
    func apply(to store: SwiftDataPhysicalKeyboardRecordStore) throws {
        switch self {
        case .rename:
            try store.saveName(identityKey: "old", productName: "Keyboard", customName: "New")
        case .assignment:
            try store.saveAssignment(
                identityKey: "old", productName: "Keyboard",
                assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.italian")
            )
        case .delete:
            try store.deleteRecord(identityKey: "old")
        case .transfer:
            try store.transferRecord(fromIdentityKey: "old", toIdentityKey: "destination", productName: "Other")
        case .insert:
            try store.saveName(identityKey: "new", productName: "New Keyboard", customName: "Desk")
        }
    }

    @MainActor
    func verify(in retriedReader: SwiftDataPhysicalKeyboardRecordStore) throws {
        switch self {
    case .rename:
        #expect(try retriedReader.record(forIdentityKey: "old")?.customName == "New")
    case .assignment:
        #expect(
            try retriedReader.record(forIdentityKey: "old")?.keyboardAssignment?.inputSourceIdentifier
                == "com.example.italian"
        )
    case .delete:
        #expect(try retriedReader.record(forIdentityKey: "old") == nil)
    case .transfer:
        #expect(try retriedReader.record(forIdentityKey: "old") == nil)
        #expect(try retriedReader.record(forIdentityKey: "destination")?.customName == "Studio")
    case .insert:
        #expect(try retriedReader.record(forIdentityKey: "new")?.customName == "Desk")
    }
    }
}

@Test("Failed record edits preserve committed data and retry the intended change", arguments: FailedRecordEdit.allCases)
@MainActor
private func failedRecordEditsPreserveCommittedData(edit: FailedRecordEdit) throws {
    let folder = URL.temporaryDirectory.appending(path: "KeyameleonPersistence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "records.store")
    let container = try makePersistenceFailureContainer(at: url)
    var fails = false
    let context = ModelContext(container)
    let session = SwiftDataPersistenceSession(modelContext: context, save: {
        if fails { throw PersistenceInjectedFailure.unavailable }
        try $0.save()
    })
    let store = SwiftDataPhysicalKeyboardRecordStore(session: session)
    try store.saveName(identityKey: "old", productName: "Keyboard", customName: "Studio")
    try store.saveAssignment(
        identityKey: "old", productName: "Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )
    try store.saveName(identityKey: "destination", productName: "Other", customName: "Travel")
    let committed = try store.allRecords().sorted { $0.identityKey < $1.identityKey }
    var changes = 0
    store.startObservingChanges { changes += 1 }
    let editRecord = { try edit.apply(to: store) }

    fails = true
    #expect(throws: PersistenceInjectedFailure.self) { try editRecord() }
    #expect(context.hasChanges == false)
    #expect(changes == 0)
    #expect(try store.allRecords().sorted { $0.identityKey < $1.identityKey } == committed)
    let reader = SwiftDataPhysicalKeyboardRecordStore(
        modelContext: ModelContext(try makePersistenceFailureContainer(at: url))
    )
    #expect(try reader.allRecords().sorted { $0.identityKey < $1.identityKey } == committed)

    fails = false
    try editRecord()
    #expect(changes == 1)
    let retriedReader = SwiftDataPhysicalKeyboardRecordStore(
        modelContext: ModelContext(try makePersistenceFailureContainer(at: url))
    )
    try edit.verify(in: retriedReader)
}

@MainActor
private func makePersistenceFailureContainer(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
    return try ModelContainer(
        for: schema, migrationPlan: PhysicalKeyboardMigrationPlan.self,
        configurations: [ModelConfiguration(schema: schema, url: url)]
    )
}

@Test("Opening failure stays actionable until explicit retry restores existing records")
@MainActor
private func openingFailureRetriesWithoutReset() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    let seed = SwiftDataPhysicalKeyboardRecordStore(modelContext: ModelContext(container))
    try seed.saveName(identityKey: "old", productName: "Keyboard", customName: "Studio")
    var fails = true
    var attempts = 0
    let session = SwiftDataPersistenceSession(openContainer: {
        attempts += 1
        if fails { throw PersistenceInjectedFailure.unavailable }
        return container
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let model = makePersistenceFailureModel(records: records, session: session)
    #expect(model.persistenceError != nil)
    #expect(model.physicalKeyboards.isEmpty)
    #expect(attempts == 1)
    model.activityTriggeredSwitching.checkAgain()
    #expect(attempts == 1)
    #expect(try seed.record(forIdentityKey: "old")?.customName == "Studio")
    fails = false
    model.retryPersistenceOperation()
    #expect(attempts == 2)
    #expect(model.persistenceError == nil)
    #expect(model.activityTriggeredSwitching.persistenceError == nil)
    #expect(model.physicalKeyboards.map(\.name) == ["Studio"])
}

@Test("Failed rename retries exact name even after disconnect", arguments: [true, false])
@MainActor
private func modelRetriesFailedRenameWithoutFalseSuccess(initiallySaved: Bool) throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), save: {
        if fails { throw PersistenceInjectedFailure.unavailable }
        try $0.save()
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makePersistenceFailureModel(records: records, session: session, discoverer: discoverer)
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 901)))
    let keyboard = try #require(model.physicalKeyboards.first)
    if initiallySaved { model.setPhysicalKeyboardName(keyboard.id, customName: "Studio") }
    fails = true
    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel")
    #expect(model.persistenceError?.contains("not saved") == true)
    #expect(model.physicalKeyboards.first?.name == (initiallySaved ? "Studio" : "Test Keyboard"))
    model.activityTriggeredSwitching.checkAgain()
    discoverer.emit(.disconnected(serviceID: 901))
    #expect(model.persistenceError?.contains("not saved") == true)
    #expect(model.physicalKeyboards.map(\.name) == (initiallySaved ? ["Studio"] : []))
    fails = false
    model.retryPersistenceOperation()
    #expect(model.persistenceError == nil)
    #expect(model.physicalKeyboards.first?.name == "Travel")
    let reader = SwiftDataPhysicalKeyboardRecordStore(modelContext: ModelContext(container))
    #expect(try reader.record(forIdentityKey: keyboard.id.rawValue)?.customName == "Travel")
}

@MainActor
private func makePersistenceFailureModel(
    records: SwiftDataPhysicalKeyboardRecordStore,
    session: SwiftDataPersistenceSession,
    discoverer: SetupModelTestPhysicalKeyboardDiscoverer = SetupModelTestPhysicalKeyboardDiscoverer()
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: records,
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
}

@Test("Compound forget rolls back records and designation together before successful retry")
@MainActor
private func compoundForgetRollsBackBothStores() throws {
    let folder = URL.temporaryDirectory.appending(path: "KeyameleonForget-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "records.store")
    let container = try makePersistenceFailureContainer(at: url)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), save: {
        if fails { throw PersistenceInjectedFailure.unavailable }
        try $0.save()
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    let identityKey = "identity:old"
    try records.saveName(identityKey: identityKey, productName: "Keyboard", customName: "Studio")
    let designation = SavedManualPhysicalKeyboardDesignation(
        identityKey: identityKey, productName: "Keyboard", confirmedName: "Studio", authenticationTag: Data([1, 2, 3])
    )
    try designations.save(designation)
    let model = makePersistenceFailureModel(records: records, session: session)
    let keyboard = try #require(model.physicalKeyboards.first)
    var changes = 0
    records.startObservingChanges { changes += 1 }

    fails = true
    model.forgetPhysicalKeyboard(keyboard.id)
    #expect(model.persistenceError?.contains("not saved") == true)
    #expect(model.physicalKeyboards.map(\.name) == ["Studio"])
    #expect(changes == 0)

    model.setPhysicalKeyboardName(keyboard.id, customName: "Must not replace pending forget")
    model.retryPersistenceOperation()
    #expect(model.persistenceError?.contains("not saved") == true)
    #expect(changes == 0)
    let readerContext = ModelContext(try makePersistenceFailureContainer(at: url))
    let recordReader = SwiftDataPhysicalKeyboardRecordStore(modelContext: readerContext)
    let designationReader = SwiftDataManualPhysicalKeyboardDesignationStore(modelContext: readerContext)
    #expect(try recordReader.record(forIdentityKey: identityKey)?.customName == "Studio")
    #expect(try designationReader.designation(forIdentityKey: identityKey) == designation)

    fails = false
    model.retryPersistenceOperation()
    #expect(model.persistenceError == nil)
    #expect(model.physicalKeyboards.isEmpty)
    #expect(changes == 1)
    let retriedContext = ModelContext(try makePersistenceFailureContainer(at: url))
    #expect(try SwiftDataPhysicalKeyboardRecordStore(modelContext: retriedContext).allRecords().isEmpty == true)
    #expect(try SwiftDataManualPhysicalKeyboardDesignationStore(modelContext: retriedContext).allDesignations().isEmpty == true)
    model.retryPersistenceOperation()
    #expect(changes == 1)
}

@Test("Fetch failure propagates instead of inventing missing records or designations")
@MainActor
private func fetchFailureDoesNotInventMissingData() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), beforeFetch: {
        if fails { throw PersistenceInjectedFailure.unavailable }
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    try records.saveName(identityKey: "old", productName: "Keyboard", customName: "Studio")
    fails = true
    #expect(throws: PersistenceInjectedFailure.self) { try records.record(forIdentityKey: "old") }
    #expect(throws: PersistenceInjectedFailure.self) { try records.allRecords() }
    #expect(throws: PersistenceInjectedFailure.self) { try designations.designation(forIdentityKey: "old") }
    #expect(throws: PersistenceInjectedFailure.self) { try designations.allDesignations() }
    fails = false
    #expect(try records.record(forIdentityKey: "old")?.customName == "Studio")
}

@Test("Read failure preserves prior assignment and stops selection until retry")
@MainActor
private func switchingReadFailurePreservesAssignment() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), beforeFetch: {
        if fails { throw PersistenceInjectedFailure.unavailable }
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.italian")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.italian", name: "Italian")
        ]),
        inputSourceSelector: selector,
        physicalKeyboardRecordStore: records,
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 903)))
    let keyboard = try #require(model.physicalKeyboards.first)
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.us")
    let switching = model.activityTriggeredSwitching
    let discovery = switching.testingPhysicalKeyboardDiscovery
    discovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 903, kind: .press))
    #expect(selector.selectCount == 1)
    let previous = switching.outcome
    fails = true
    switching.checkAgain()
    #expect(switching.persistenceError != nil)
    #expect(switching.outcome == previous)
    #expect(switching.testingWantedKeyboardAssignmentIdentifier == "com.example.us")
    selector.current = "com.example.italian"
    discovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 903, kind: .press))
    switching.retryNow()
    #expect(selector.selectCount == 1)
    fails = false
    model.retryPersistenceOperation()
    #expect(switching.persistenceError == nil)
    discovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 903, kind: .press))
    #expect(selector.selectCount == 2)
    #expect(selector.current == "com.example.us")
}

@Test("Canceling designation preserves an unrelated failed rename for Retry")
@MainActor
private func designationCancellationKeepsUnrelatedRetry() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), save: {
        if fails { throw PersistenceInjectedFailure.unavailable }
        try $0.save()
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makePersistenceFailureModel(records: records, session: session, discoverer: discoverer)
    startAndCheck(model)
    for productID in [UInt32(100), 200] {
        discoverer.emit(.connected(PhysicalKeyboardHardwareFacts(
            serviceID: UInt64(productID),
            identity: PhysicalKeyboardIdentity(
                rawValue: "macos.keyboard.ambiguous", isBuiltIn: false, serialNumber: "same-serial"
            ),
            name: "Ambiguous Board", transport: .usb, isBuiltIn: false,
            vendorID: 500, productID: productID, modelNumber: "Model", serialNumber: "same-serial"
        )))
    }
    let ambiguous = try #require(model.physicalKeyboards.first { !$0.isAssignable })
    model.startManualDesignation(for: ambiguous.id)
    #expect(model.manualDesignationPhase == .awaitingRemoval(ambiguous.id))
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 906)))
    let keyboard = try #require(model.physicalKeyboards.first { $0.isAssignable })
    fails = true
    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel")
    model.cancelManualDesignation()
    #expect(model.manualDesignationPhase == .idle)
    #expect(model.persistenceError?.contains("not saved") == true)
    fails = false
    model.retryPersistenceOperation()
    #expect(model.persistenceError == nil)
    #expect(try records.record(forIdentityKey: keyboard.id.rawValue)?.customName == "Travel")
}
