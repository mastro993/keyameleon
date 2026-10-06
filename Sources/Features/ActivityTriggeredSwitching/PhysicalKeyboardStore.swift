import Foundation
@preconcurrency import SwiftData

@MainActor
protocol PhysicalKeyboardRecordStoring: AnyObject {
    func record(forIdentityKey identityKey: String) throws -> SavedPhysicalKeyboardRecord?
    func allRecords() throws -> [SavedPhysicalKeyboardRecord]
    func startObservingChanges(onChange: @escaping @MainActor () -> Void)
    func stopObservingChanges()
    func saveName(
        identityKey: String,
        productName: String,
        customName: String?
    ) throws
    func saveAssignment(
        identityKey: String,
        productName: String,
        assignment: KeyboardAssignment?
    ) throws
    func deleteRecord(identityKey: String) throws
    func transferRecord(
        fromIdentityKey: String,
        toIdentityKey: String,
        productName: String
    ) throws
}

extension PhysicalKeyboardRecordStoring {
    func startObservingChanges(onChange: @escaping @MainActor () -> Void) {}
    func stopObservingChanges() {}

    /// Moves the only old built-in record to the fixed local identity.
    /// Multiple old records are left untouched for the replacement flow.
    @discardableResult
    func migrateSingleOldBuiltInRecord(
        toIdentityKey identityKey: String,
        productName: String
    ) throws -> SavedPhysicalKeyboardRecord? {
        guard try record(forIdentityKey: identityKey) == nil else {
            return nil
        }

        let oldRecords = try allRecords().filter {
            $0.isBuiltInIdentity && $0.identityKey != identityKey
        }
        guard oldRecords.count == 1, let oldRecord = oldRecords.first else {
            return nil
        }

        try transferRecord(
            fromIdentityKey: oldRecord.identityKey,
            toIdentityKey: identityKey,
            productName: productName
        )
        return oldRecord
    }
}

enum PhysicalKeyboardSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            PhysicalKeyboardRecordModel.self,
            ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel.self
        ]
    }

    @Model
    final class PhysicalKeyboardRecordModel {
        @Attribute(.unique) var identityKey: String
        var productName: String
        var customName: String?
        var assignedInputSourceIdentifier: String?

        init(
            identityKey: String,
            productName: String,
            customName: String? = nil,
            assignedInputSourceIdentifier: String? = nil
        ) {
            self.identityKey = identityKey
            self.productName = productName
            self.customName = customName
            self.assignedInputSourceIdentifier = assignedInputSourceIdentifier
        }

        var savedRecord: SavedPhysicalKeyboardRecord {
            SavedPhysicalKeyboardRecord(
                identityKey: identityKey,
                productName: productName,
                customName: customName,
                keyboardAssignment: assignedInputSourceIdentifier.flatMap {
                    KeyboardAssignment(inputSourceIdentifier: $0)
                }
            )
        }
    }
}

enum PhysicalKeyboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PhysicalKeyboardSchemaV1.self]
    }

    // Explicit empty plan: V1 is the baseline. Future schema versions add stages here.
    static var stages: [MigrationStage] {
        []
    }
}

@MainActor
final class SwiftDataPhysicalKeyboardRecordStore: PhysicalKeyboardRecordStoring {
    let session: SwiftDataPersistenceSession
    private var onChange: (@MainActor () -> Void)?

    init(modelContext: ModelContext) {
        session = SwiftDataPersistenceSession(modelContext: modelContext)
    }

    init(session: SwiftDataPersistenceSession) {
        self.session = session
    }

    nonisolated static func makeConfiguration(
        inMemory: Bool = false,
        buildIdentity: AppBuildIdentity = .current
    ) -> ModelConfiguration {
        let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
        let legacyConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        guard !inMemory else { return legacyConfiguration }
        let storeURL = legacyConfiguration.url.deletingLastPathComponent()
            .appending(path: buildIdentity.storageFolderName, directoryHint: .isDirectory)
            .appending(path: legacyConfiguration.url.lastPathComponent)
        return ModelConfiguration(schema: schema, url: storeURL)
    }

    static func makeContainer(
        inMemory: Bool = false,
        buildIdentity: AppBuildIdentity = .current
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
        let configuration = makeConfiguration(inMemory: inMemory, buildIdentity: buildIdentity)
        if !inMemory {
            try prepareStore(
                from: ModelConfiguration(schema: schema).url,
                to: configuration.url,
                buildIdentity: buildIdentity
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: PhysicalKeyboardMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func prepareStore(
        from legacyURL: URL,
        to storeURL: URL,
        buildIdentity: AppBuildIdentity
    ) throws {
        if buildIdentity.importsLegacyStore {
            try PhysicalKeyboardStoreMigration.prepareStore(from: legacyURL, to: storeURL)
        } else {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
    }

    func record(forIdentityKey identityKey: String) throws -> SavedPhysicalKeyboardRecord? {
        try fetchModel(identityKey: identityKey)?.savedRecord
    }

    func startObservingChanges(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func stopObservingChanges() {
        onChange = nil
    }

    func allRecords() throws -> [SavedPhysicalKeyboardRecord] {
        try session.fetch(FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>())
            .map(\.savedRecord)
    }

    func saveName(
        identityKey: String,
        productName: String,
        customName: String?
    ) throws {
        try session.transaction {
            let model = try upsertModel(identityKey: identityKey, productName: productName)
            model.customName = customName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    func saveAssignment(
        identityKey: String,
        productName: String,
        assignment: KeyboardAssignment?
    ) throws {
        try session.transaction {
            let model = try upsertModel(identityKey: identityKey, productName: productName)
            model.assignedInputSourceIdentifier = assignment?.inputSourceIdentifier
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    func deleteRecord(identityKey: String) throws {
        try session.transaction {
            guard let model = try fetchModel(identityKey: identityKey) else {
                return
            }

            try session.modelContext().delete(model)
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    func transferRecord(
        fromIdentityKey: String,
        toIdentityKey: String,
        productName: String
    ) throws {
        try session.transaction {
            guard let source = try fetchModel(identityKey: fromIdentityKey) else {
                return
            }

            let destination = try upsertModel(identityKey: toIdentityKey, productName: productName)
            destination.customName = source.customName
            destination.assignedInputSourceIdentifier = source.assignedInputSourceIdentifier
            try session.modelContext().delete(source)
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    private func upsertModel(
        identityKey: String,
        productName: String
    ) throws -> PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel {
        if let existing = try fetchModel(identityKey: identityKey) {
            existing.productName = productName
            return existing
        }

        let model = PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
            identityKey: identityKey,
            productName: productName
        )
        try session.modelContext().insert(model)
        return model
    }

    private func fetchModel(
        identityKey: String
    ) throws -> PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel? {
        var descriptor = FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>(
            predicate: #Predicate { $0.identityKey == identityKey }
        )
        descriptor.fetchLimit = 1

        return try session.fetch(descriptor).first
    }
}

@MainActor
final class InMemoryPhysicalKeyboardRecordStore: PhysicalKeyboardRecordStoring {
    private var records: [String: SavedPhysicalKeyboardRecord] = [:]
    private var onChange: (@MainActor () -> Void)?

    func record(forIdentityKey identityKey: String) -> SavedPhysicalKeyboardRecord? {
        records[identityKey]
    }

    func startObservingChanges(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func stopObservingChanges() {
        onChange = nil
    }

    func allRecords() -> [SavedPhysicalKeyboardRecord] {
        Array(records.values)
    }

    func saveName(
        identityKey: String,
        productName: String,
        customName: String?
    ) {
        let existing = records[identityKey]
        records[identityKey] = SavedPhysicalKeyboardRecord(
            identityKey: identityKey,
            productName: productName,
            customName: customName,
            keyboardAssignment: existing?.keyboardAssignment
        )
        onChange?()
    }

    func saveAssignment(
        identityKey: String,
        productName: String,
        assignment: KeyboardAssignment?
    ) {
        let existing = records[identityKey]
        records[identityKey] = SavedPhysicalKeyboardRecord(
            identityKey: identityKey,
            productName: productName,
            customName: existing?.customName,
            keyboardAssignment: assignment
        )
        onChange?()
    }

    func deleteRecord(identityKey: String) {
        guard records.removeValue(forKey: identityKey) != nil else {
            return
        }

        onChange?()
    }

    func transferRecord(
        fromIdentityKey: String,
        toIdentityKey: String,
        productName: String
    ) {
        guard let source = records[fromIdentityKey] else {
            return
        }

        records[toIdentityKey] = SavedPhysicalKeyboardRecord(
            identityKey: toIdentityKey,
            productName: productName,
            customName: source.customName,
            keyboardAssignment: source.keyboardAssignment
        )
        records.removeValue(forKey: fromIdentityKey)
        onChange?()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
