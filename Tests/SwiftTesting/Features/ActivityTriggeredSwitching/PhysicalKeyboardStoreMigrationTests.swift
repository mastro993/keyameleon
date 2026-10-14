import Foundation
import SQLite3
@preconcurrency import SwiftData
import Synchronization
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
    let saved = try #require(try records.record(forIdentityKey: identityKey))
    #expect(saved.productName == "Test Keyboard")
    #expect(saved.customName == "Studio")
    #expect(saved.keyboardAssignment == KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.Italian"))
    let designations = SwiftDataManualPhysicalKeyboardDesignationStore(modelContext: migratedContext)
    #expect(try designations.designation(forIdentityKey: identityKey) == SavedManualPhysicalKeyboardDesignation(
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
    #expect(try store.record(forIdentityKey: "keyboard")?.customName == "Current")
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
    #expect(try store.record(forIdentityKey: "keyboard")?.customName == "Recovered")
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

@Test("A legacy store that belongs to another app is not imported")
@MainActor
func storeRelocationSkipsForeignLegacyStore() throws {
    try expectLegacyStoreSkipped(alsoHoldsKeyboards: false)
}

@Test("A legacy store that mixes Keyameleon's keyboards with another app's data is not imported")
@MainActor
func storeRelocationSkipsMixedLegacyStore() throws {
    try expectLegacyStoreSkipped(alsoHoldsKeyboards: true)
}

@Test("Only a store with Keyameleon's keyboard table and no other app's tables is imported", arguments: [
    ("CREATE TABLE ZPHYSICALKEYBOARDRECORDMODEL (Z_PK INTEGER PRIMARY KEY AUTOINCREMENT)", true),
    ("PRAGMA user_version = 1", false),
    ("CREATE TABLE Z_METADATA (Z_VERSION INTEGER); CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER)", false),
    ("CREATE TABLE ZPHYSICALKEYBOARDRECORDMODEL (Z_PK INTEGER); CREATE TABLE other_app_records (id INTEGER)", false),
])
func storeRelocationImportsOnlyKeyameleonTables(legacySQL: String, isImported: Bool) throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    var database: OpaquePointer?
    try #require(sqlite3_open(legacyURL.path, &database) == SQLITE_OK)
    let execResult = sqlite3_exec(database, legacySQL, nil, nil, nil)
    sqlite3_close(database)
    try #require(execResult == SQLITE_OK)

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)

    #expect(FileManager.default.fileExists(atPath: destinationURL.path) == isImported)
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

/// Stands in for another app's model at SwiftData's shared default path.
@Model
final class ForeignAppRequestModel {
    var url: String

    init(url: String) {
        self.url = url
    }
}

@MainActor
private func expectLegacyStoreSkipped(alsoHoldsKeyboards: Bool) throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let destinationURL = root.appending(path: "Keyameleon/default.store")
    let models: [any PersistentModel.Type] = alsoHoldsKeyboards
        ? [ForeignAppRequestModel.self, PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel.self]
        : [ForeignAppRequestModel.self]
    let schema = Schema(models)
    let legacy = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: legacyURL)])
    let context = ModelContext(legacy)
    context.insert(ForeignAppRequestModel(url: "https://example.com"))
    if alsoHoldsKeyboards {
        context.insert(PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
            identityKey: "keyboard", productName: "Test Keyboard", customName: "Studio"
        ))
    }
    try context.save()
    let legacyBytes = try Data(contentsOf: legacyURL)
    let walURL = URL(fileURLWithPath: legacyURL.path + "-wal")
    let walBytes = try Data(contentsOf: walURL)
    let warnings = Mutex<[String]>([])
    Log.start(LogWriter { level, _, message in
        if level == .warning { warnings.withLock { $0.append(message) } }
    })
    defer { Log.stop() }

    try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: destinationURL)

    #expect(warnings.withLock { $0 }.contains("Skipped the legacy store because it holds another app's data"))
    #expect(try Data(contentsOf: legacyURL) == legacyBytes)
    #expect(try Data(contentsOf: walURL) == walBytes)
    #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    let stagingURL = destinationURL.deletingLastPathComponent().appending(path: ".store-migration")
    #expect(!FileManager.default.fileExists(atPath: stagingURL.path))
    let fresh = try migrationTestContainer(at: destinationURL)
    let descriptor = FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>()
    #expect(try ModelContext(fresh).fetchCount(descriptor) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ForeignAppRequestModel>()) == 1)
}

@Test("Only the release imports the legacy store; a Debug store starts empty", arguments: [
    AppBuildIdentity.release, AppBuildIdentity.debug
])
@MainActor
func legacyStoreImportFollowsBuildIdentity(buildIdentity: AppBuildIdentity) throws {
    let root = try migrationTestDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacyURL = root.appending(path: "default.store")
    let storeURL = root.appending(path: buildIdentity.storageFolderName).appending(path: "default.store")
    let legacy = try migrationTestContainer(at: legacyURL)
    let legacyContext = ModelContext(legacy)
    legacyContext.insert(PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
        identityKey: "keyboard",
        productName: "Test Keyboard",
        customName: "Legacy",
        assignedInputSourceIdentifier: nil
    ))
    try legacyContext.save()
    let legacyBytes = try Data(contentsOf: legacyURL)

    try SwiftDataPhysicalKeyboardRecordStore.prepareStore(
        from: legacyURL, to: storeURL, buildIdentity: buildIdentity
    )

    #expect(try Data(contentsOf: legacyURL) == legacyBytes)
    #expect(FileManager.default.fileExists(atPath: storeURL.deletingLastPathComponent().path))
    #expect(FileManager.default.fileExists(atPath: storeURL.path) == buildIdentity.importsLegacyStore)
    let store = SwiftDataPhysicalKeyboardRecordStore(modelContext: ModelContext(try migrationTestContainer(at: storeURL)))
    let imported = try store.record(forIdentityKey: "keyboard")?.customName
    #expect(imported == (buildIdentity == .release ? "Legacy" : nil))
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
