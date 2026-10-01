import Foundation
import SwiftData
import Testing
@testable import Keyameleon

private enum SavedChangeTestCase: CaseIterable {
    case rename, assign, replace, forget, designate
}

private enum SavedChangeTestFailure: Error {
    case unavailable
}

@Test("Saved changes retry the captured command and publish only committed records", arguments: SavedChangeTestCase.allCases)
@MainActor
private func savedChangesRetryAtomically(edit: SavedChangeTestCase) throws {
    let folder = URL.temporaryDirectory.appending(path: "SavedChanges-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "records.store")
    let container = try makeSavedChangeTestContainer(at: url)
    let context = ModelContext(container)
    var fails = false
    var saveAttempts = 0
    let session = SwiftDataPersistenceSession(modelContext: context, save: {
        saveAttempts += 1
        if fails { throw SavedChangeTestFailure.unavailable }
        try $0.save()
    })
    let records = SwiftDataPhysicalKeyboardRecordStore(session: session)
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    let changes = SavedPhysicalKeyboardChanges(records: records, designations: designations)
    let assignment = KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    let old = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:old"), productName: "Keyboard",
        customName: "Studio", transport: .usb, isBuiltIn: false, assignmentState: .unassigned,
        connectedServiceCount: 0, connectionState: .disconnected, isActive: false
    )
    let destination = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:destination"), productName: "Other",
        customName: "Travel", transport: .usb, isBuiltIn: false, assignmentState: .unassigned,
        connectedServiceCount: 1, connectionState: .connected, isActive: false
    )
    let originalDesignation = SavedManualPhysicalKeyboardDesignation(
        identityKey: old.id.rawValue, productName: old.productName,
        confirmedName: "Studio", authenticationTag: Data([1, 2, 3])
    )
    let newDesignation = SavedManualPhysicalKeyboardDesignation(
        identityKey: old.id.rawValue, productName: old.productName,
        confirmedName: "Desk", authenticationTag: Data([4, 5, 6])
    )
    try records.saveName(identityKey: old.id.rawValue, productName: old.productName, customName: old.customName)
    try records.saveAssignment(identityKey: old.id.rawValue, productName: old.productName, assignment: assignment)
    try records.saveName(
        identityKey: destination.id.rawValue, productName: destination.productName, customName: destination.customName
    )
    try designations.save(originalDesignation)
    let originalRecords = try records.allRecords().sorted { $0.identityKey < $1.identityKey }
    let destinationRecord = try #require(try records.record(forIdentityKey: destination.id.rawValue))
    let originalRecord = try #require(try records.record(forIdentityKey: old.id.rawValue))
    let command: SavedPhysicalKeyboardChange
    let expectedRecords: [SavedPhysicalKeyboardRecord]
    let expectedDesignations: [SavedManualPhysicalKeyboardDesignation]
    switch edit {
    case .rename:
        command = .rename(keyboard: old, customName: "Desk")
        expectedRecords = [destinationRecord, SavedPhysicalKeyboardRecord(
            identityKey: old.id.rawValue, productName: old.productName,
            customName: "Desk", keyboardAssignment: assignment
        )]
        expectedDesignations = [originalDesignation]
    case .assign:
        command = .assign(keyboard: old, assignment: nil)
        expectedRecords = [destinationRecord, SavedPhysicalKeyboardRecord(
            identityKey: old.id.rawValue, productName: old.productName, customName: originalRecord.customName
        )]
        expectedDesignations = [originalDesignation]
    case .replace:
        command = .replace(old: old, new: destination)
        expectedRecords = [SavedPhysicalKeyboardRecord(
            identityKey: destination.id.rawValue, productName: destination.productName,
            customName: originalRecord.customName, keyboardAssignment: assignment
        )]
        expectedDesignations = []
    case .forget:
        command = .forget(keyboard: old)
        expectedRecords = [destinationRecord]
        expectedDesignations = []
    case .designate:
        command = .designate(newDesignation)
        expectedRecords = [destinationRecord, SavedPhysicalKeyboardRecord(
            identityKey: old.id.rawValue, productName: old.productName,
            customName: newDesignation.confirmedName, keyboardAssignment: assignment
        )]
        expectedDesignations = [newDesignation]
    }
    var notifications = 0
    records.startObservingChanges {
        notifications += 1
        do {
            try expectSavedChangeTestState(at: url, records: expectedRecords, designations: expectedDesignations)
        } catch {
            Issue.record(error)
        }
    }
    defer { records.stopObservingChanges() }
    saveAttempts = 0
    fails = true
    #expect(changes.perform(command) == .failed)
    #expect(changes.hasPendingChange)
    #expect(saveAttempts == 1)
    #expect(changes.perform(.rename(keyboard: destination, customName: "Competing edit")) == .blocked)
    #expect(saveAttempts == 1)
    #expect(changes.retry() == .failed)
    #expect(changes.retry() == .failed)
    #expect(saveAttempts == 3)
    #expect(changes.hasPendingChange)
    #expect(context.hasChanges == false)
    #expect(notifications == 0)
    #expect(try records.allRecords().sorted { $0.identityKey < $1.identityKey } == originalRecords)
    #expect(try designations.allDesignations() == [originalDesignation])
    try expectSavedChangeTestState(at: url, records: originalRecords, designations: [originalDesignation])

    fails = false
    let result = changes.retry()
    #expect(result == .committed(command))
    #expect(saveAttempts == 4)
    #expect(changes.hasPendingChange == false)
    #expect(notifications == 1)
    try expectSavedChangeTestState(at: url, records: expectedRecords, designations: expectedDesignations)
    #expect(changes.retry() == .nothingPending)
    #expect(notifications == 1)
    #expect(saveAttempts == 4)
}

@MainActor
private func makeSavedChangeTestContainer(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
    return try ModelContainer(
        for: schema, migrationPlan: PhysicalKeyboardMigrationPlan.self,
        configurations: [ModelConfiguration(schema: schema, url: url)]
    )
}

@MainActor
private func expectSavedChangeTestState(
    at url: URL,
    records expectedRecords: [SavedPhysicalKeyboardRecord],
    designations expectedDesignations: [SavedManualPhysicalKeyboardDesignation]
) throws {
    let context = ModelContext(try makeSavedChangeTestContainer(at: url))
    let records = SwiftDataPhysicalKeyboardRecordStore(modelContext: context)
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(modelContext: context)
    #expect(try records.allRecords().sorted { $0.identityKey < $1.identityKey } == expectedRecords)
    #expect(try designations.allDesignations() == expectedDesignations)
}
