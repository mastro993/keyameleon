import Foundation
@preconcurrency import SwiftData

@MainActor
protocol PhysicalKeyboardRecordStoring: AnyObject {
    func record(forIdentityKey identityKey: String) -> SavedPhysicalKeyboardRecord?
    func allRecords() -> [SavedPhysicalKeyboardRecord]
    func saveName(
        identityKey: String,
        productName: String,
        customName: String?
    )
    func saveAssignment(
        identityKey: String,
        productName: String,
        assignment: KeyboardAssignment?
    )
    func deleteRecord(identityKey: String)
    func transferRecord(
        fromIdentityKey: String,
        toIdentityKey: String,
        productName: String
    )
}

enum PhysicalKeyboardSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            PhysicalKeyboardRecordModel.self,
            ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel.self,
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
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    static func makeContainer(
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PhysicalKeyboardSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PhysicalKeyboardMigrationPlan.self,
            configurations: [configuration]
        )
    }

    func record(forIdentityKey identityKey: String) -> SavedPhysicalKeyboardRecord? {
        fetchModel(identityKey: identityKey)?.savedRecord
    }

    func allRecords() -> [SavedPhysicalKeyboardRecord] {
        do {
            return try modelContext
                .fetch(FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>())
                .map(\.savedRecord)
        } catch {
            fatalError("SwiftData fetch failed for Physical Keyboard records: \(error)")
        }
    }

    func saveName(
        identityKey: String,
        productName: String,
        customName: String?
    ) {
        let model = upsertModel(identityKey: identityKey, productName: productName)
        model.customName = customName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        save()
    }

    func saveAssignment(
        identityKey: String,
        productName: String,
        assignment: KeyboardAssignment?
    ) {
        let model = upsertModel(identityKey: identityKey, productName: productName)
        model.assignedInputSourceIdentifier = assignment?.inputSourceIdentifier
        save()
    }

    func deleteRecord(identityKey: String) {
        guard let model = fetchModel(identityKey: identityKey) else {
            return
        }

        modelContext.delete(model)
        save()
    }

    func transferRecord(
        fromIdentityKey: String,
        toIdentityKey: String,
        productName: String
    ) {
        guard let source = fetchModel(identityKey: fromIdentityKey) else {
            return
        }

        let destination = upsertModel(identityKey: toIdentityKey, productName: productName)
        destination.customName = source.customName
        destination.assignedInputSourceIdentifier = source.assignedInputSourceIdentifier
        modelContext.delete(source)
        save()
    }

    private func upsertModel(
        identityKey: String,
        productName: String
    ) -> PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel {
        if let existing = fetchModel(identityKey: identityKey) {
            existing.productName = productName
            return existing
        }

        let model = PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel(
            identityKey: identityKey,
            productName: productName
        )
        modelContext.insert(model)
        return model
    }

    private func fetchModel(
        identityKey: String
    ) -> PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel? {
        var descriptor = FetchDescriptor<PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel>(
            predicate: #Predicate { $0.identityKey == identityKey }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            fatalError("SwiftData fetch failed for Physical Keyboard records: \(error)")
        }
    }

    private func save() {
        guard modelContext.hasChanges else {
            return
        }

        do {
            try modelContext.save()
        } catch {
            fatalError("SwiftData save failed for Physical Keyboard records: \(error)")
        }
    }
}

@MainActor
final class InMemoryPhysicalKeyboardRecordStore: PhysicalKeyboardRecordStoring {
    private var records: [String: SavedPhysicalKeyboardRecord] = [:]

    func record(forIdentityKey identityKey: String) -> SavedPhysicalKeyboardRecord? {
        records[identityKey]
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
    }

    func deleteRecord(identityKey: String) {
        records.removeValue(forKey: identityKey)
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
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
