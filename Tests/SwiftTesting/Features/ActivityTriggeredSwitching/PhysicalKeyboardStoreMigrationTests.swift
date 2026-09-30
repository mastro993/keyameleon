import Foundation
@preconcurrency import SwiftData
import Testing
@testable import Keyameleon

@Test("Store relocation preserves saved keyboard data and live WAL without changing the legacy store")
@MainActor
func storeRelocationPreservesSavedKeyboardDataAndLiveWAL() throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    let legacy = try migrationTestContainer(at: legacyURL)
    let context = ModelContext(legacy)
    let identityKey = "identity:test-keyboard|anchor:serial:studio"
    let tag = Data((0..<32).map(UInt8.init))
    context.insert(PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
        identityKey: identityKey,
        productName: "Test Keyboard",
        customName: "Studio",
        assignedInputSourceIdentifier: "com.apple.keylayout.Italian"
    ))
    context.insert(ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel(
        identityKey: identityKey,
        productName: "Test Keyboard",
        confirmedName: "Studio",
        authenticationTag: tag
    ))
    try context.save()
    let legacyBytes = try Data(contentsOf: legacyURL)
    let walURL = URL(fileURLWithPath: legacyURL.path + "-wal")
    let walBytes = try Data(contentsOf: walURL)
    try #require(walBytes.count > 32)

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)

    #expect(try Data(contentsOf: legacyURL) == legacyBytes)
    #expect(try Data(contentsOf: walURL) == walBytes)
    let migrated = try migrationTestContainer(at: destinationURL)
    let migratedContext = ModelContext(migrated)
    let records = SwiftDataPhysicalKeyboardRecordStore(modelContext: migratedContext)
    let saved = try #require(records.record(forIdentityKey: identityKey))
    #expect(saved.productName == "Test Keyboard")
    #expect(saved.customName == "Studio")
    #expect(saved.keyboardAssignment == KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.Italian"))
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(modelContext: migratedContext)
    #expect(designations.designation(forIdentityKey: identityKey) == SavedManualPhysicalKeyboardDesignation(
        identityKey: identityKey,
        productName: "Test Keyboard",
        confirmedName: "Studio",
        authenticationTag: tag
    ))
    #expect(try context.fetchCount(FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>()) == 1)
}

@Test("An existing destination store wins over legacy data")
@MainActor
func storeRelocationKeepsExistingDestination() throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    try FileManager.default.createDirectory(
        at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let legacy = try migrationTestContainer(at: legacyURL)
    let destination = try migrationTestContainer(at: destinationURL)
    let legacyContext = ModelContext(legacy)
    let destinationContext = ModelContext(destination)
    for (context, name) in [(legacyContext, "Legacy"), (destinationContext, "Current")] {
        context.insert(PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
            identityKey: "keyboard",
            productName: "Test Keyboard",
            customName: name
        ))
        try context.save()
    }
    let destinationBytes = try Data(contentsOf: destinationURL)

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)

    #expect(try Data(contentsOf: destinationURL) == destinationBytes)
    let reopened = try migrationTestContainer(at: destinationURL)
    let store = SwiftDataPhysicalKeyboardRecordStore(modelContext: ModelContext(reopened))
    #expect(store.record(forIdentityKey: "keyboard")?.customName == "Current")
    #expect(try legacyContext.fetchCount(FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>()) == 1)
}

@Test("An interrupted staged migration retries from the intact legacy store")
@MainActor
func storeRelocationRetriesInterruptedStaging() throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    let legacy = try migrationTestContainer(at: legacyURL)
    let context = ModelContext(legacy)
    context.insert(PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
        identityKey: "keyboard", productName: "Test Keyboard", customName: "Recovered"
    ))
    try context.save()
    let stagingURL = destinationURL.deletingLastPathComponent().appending(path: ".store-migration")
    try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
    try Data("incomplete database".utf8).write(to: stagingURL.appending(path: "default.store"))

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)

    let migrated = try migrationTestContainer(at: destinationURL)
    let store = SwiftDataPhysicalKeyboardRecordStore(modelContext: ModelContext(migrated))
    #expect(store.record(forIdentityKey: "keyboard")?.customName == "Recovered")
    #expect(!FileManager.default.fileExists(atPath: stagingURL.path))
    #expect(try context.fetchCount(FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>()) == 1)
}

@Test("Corrupt legacy data fails migration without publishing or changing the source")
func storeRelocationRejectsCorruptLegacyData() throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    let bytes = Data("corrupt legacy database".utf8)
    try bytes.write(to: legacyURL)

    #expect(throws: (any Error).self) {
        try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)
    }

    #expect(try Data(contentsOf: legacyURL) == bytes)
    #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
}

@Test("Fresh installs create their first SwiftData store in the application folder")
@MainActor
func freshInstallCreatesApplicationStore() throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)
    let container = try migrationTestContainer(at: destinationURL)

    #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    let descriptor = FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>()
    #expect(try ModelContext(container).fetchCount(descriptor) == 0)
}

@Test("Orphan destination sidecars are preserved and block store creation", arguments: ["-wal", "-shm"])
func storeRelocationRejectsOrphanDestinationSidecars(suffix: String) throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    try FileManager.default.createDirectory(
        at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let sidecarURL = URL(fileURLWithPath: destinationURL.path + suffix)
    let bytes = Data("orphan sidecar".utf8)
    try bytes.write(to: sidecarURL)

    #expect(throws: (any Error).self) {
        try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)
    }

    #expect(try Data(contentsOf: sidecarURL) == bytes)
    #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
}

private func migrationTestDirectory() throws -> URL {
    let url = URL.temporaryDirectory.appending(path: "KeyameleonMigration-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
private func migrationTestContainer(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
    return try ModelContainer(
        for: schema,
        migrationPlan: PhysicalKeyboardMigrationPlan.self,
        configurations: [ModelConfiguration(schema: schema, url: url)]
    )
}
