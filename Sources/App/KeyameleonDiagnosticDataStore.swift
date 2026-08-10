import Foundation
@preconcurrency import SwiftData

// MARK: - In-memory store


@MainActor
final class InMemoryDiagnosticDataStore: DiagnosticDataStoring {
    private var records: [UUID: DiagnosticRecord] = [:]
    private var tokensByLinkageKey: [String: TemporaryPhysicalKeyboardToken] = [:]

    func allRecords() -> [DiagnosticRecord] {
        Array(records.values)
    }

    func insert(_ record: DiagnosticRecord) {
        records[record.id] = record
    }

    func delete(ids: [UUID]) {
        for id in ids {
            records.removeValue(forKey: id)
        }
    }

    func deleteAll() {
        records.removeAll()
        tokensByLinkageKey.removeAll()
    }

    func delete(matchingToken token: TemporaryPhysicalKeyboardToken) {
        records = records.filter { $0.value.physicalKeyboardToken != token }
    }

    func token(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) -> TemporaryPhysicalKeyboardToken? {
        tokensByLinkageKey[linkageKey.rawValue]
    }

    func setToken(_ token: TemporaryPhysicalKeyboardToken, forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) {
        tokensByLinkageKey[linkageKey.rawValue] = token
    }

    func removeToken(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) {
        tokensByLinkageKey.removeValue(forKey: linkageKey.rawValue)
    }
}

// MARK: - SwiftData

enum DiagnosticDataSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [DiagnosticRecordModel.self, DiagnosticTokenMapModel.self]
    }

    @Model
    final class DiagnosticRecordModel {
        @Attribute(.unique) var recordID: String
        var recordedAt: Date
        var categoryRaw: String
        var codeRaw: String
        var physicalKeyboardTokenRaw: String?
        var sequenceNumber: Int64?
        var relativeMilliseconds: Int64?
        var switchingStatusRaw: String?
        var insertionOrder: Int64

        init(from record: DiagnosticRecord) {
            recordID = record.id.uuidString
            recordedAt = record.recordedAt
            categoryRaw = record.category.rawValue
            codeRaw = record.code.rawValue
            physicalKeyboardTokenRaw = record.physicalKeyboardToken?.rawValue.uuidString
            sequenceNumber = record.sequenceNumber.map { Int64(bitPattern: $0) }
            relativeMilliseconds = record.relativeMilliseconds
            switchingStatusRaw = record.switchingStatus?.rawValue
            insertionOrder = Int64(bitPattern: record.insertionOrder)
        }

        var diagnosticRecord: DiagnosticRecord {
            guard
                let id = UUID(uuidString: recordID),
                let code = DiagnosticEventCode(rawValue: codeRaw)
            else {
                fatalError("Corrupt Diagnostic Data row: id=\(recordID) code=\(codeRaw)")
            }

            let token = physicalKeyboardTokenRaw
                .flatMap(UUID.init(uuidString:))
                .map { TemporaryPhysicalKeyboardToken(rawValue: $0) }
            let switchingStatus = switchingStatusRaw.flatMap(SwitchingStatus.init(rawValue:))
            let sequence = sequenceNumber.map { UInt64(bitPattern: $0) }

            return DiagnosticRecord(
                id: id,
                recordedAt: recordedAt,
                code: code,
                physicalKeyboardToken: token,
                sequenceNumber: sequence,
                relativeMilliseconds: relativeMilliseconds,
                switchingStatus: switchingStatus,
                insertionOrder: UInt64(bitPattern: insertionOrder)
            )
        }
    }

    @Model
    final class DiagnosticTokenMapModel {
        @Attribute(.unique) var linkageKeyRaw: String
        var tokenRaw: String

        init(linkageKey: DiagnosticIdentityLinkageKey, token: TemporaryPhysicalKeyboardToken) {
            self.linkageKeyRaw = linkageKey.rawValue
            tokenRaw = token.rawValue.uuidString
        }

        var token: TemporaryPhysicalKeyboardToken? {
            UUID(uuidString: tokenRaw).map { TemporaryPhysicalKeyboardToken(rawValue: $0) }
        }
    }
}

enum DiagnosticDataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DiagnosticDataSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

@MainActor
final class SwiftDataDiagnosticDataStore: DiagnosticDataStoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: DiagnosticDataSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            let directory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Keyameleon", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            configuration = ModelConfiguration(
                schema: schema,
                url: directory.appendingPathComponent("DiagnosticData.store")
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: DiagnosticDataMigrationPlan.self,
            configurations: [configuration]
        )
    }

    func allRecords() -> [DiagnosticRecord] {
        do {
            return try modelContext
                .fetch(FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticRecordModel>())
                .map(\.diagnosticRecord)
        } catch {
            fatalError("SwiftData fetch failed for Diagnostic Data: \(error)")
        }
    }

    func insert(_ record: DiagnosticRecord) {
        modelContext.insert(DiagnosticDataSchemaV1.DiagnosticRecordModel(from: record))
        save()
    }

    func delete(ids: [UUID]) {
        let idStrings = Set(ids.map(\.uuidString))
        do {
            let models = try modelContext.fetch(
                FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticRecordModel>()
            )
            for model in models where idStrings.contains(model.recordID) {
                modelContext.delete(model)
            }
            save()
        } catch {
            fatalError("SwiftData delete failed for Diagnostic Data: \(error)")
        }
    }

    func deleteAll() {
        do {
            let models = try modelContext.fetch(
                FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticRecordModel>()
            )
            for model in models {
                modelContext.delete(model)
            }
            let tokenModels = try modelContext.fetch(
                FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticTokenMapModel>()
            )
            for model in tokenModels {
                modelContext.delete(model)
            }
            save()
        } catch {
            fatalError("SwiftData deleteAll failed for Diagnostic Data: \(error)")
        }
    }

    func delete(matchingToken token: TemporaryPhysicalKeyboardToken) {
        let tokenString = token.rawValue.uuidString
        do {
            let models = try modelContext.fetch(
                FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticRecordModel>()
            )
            for model in models where model.physicalKeyboardTokenRaw == tokenString {
                modelContext.delete(model)
            }
            save()
        } catch {
            fatalError("SwiftData token delete failed for Diagnostic Data: \(error)")
        }
    }

    func token(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) -> TemporaryPhysicalKeyboardToken? {
        fetchTokenModel(linkageKey: linkageKey)?.token
    }

    func setToken(_ token: TemporaryPhysicalKeyboardToken, forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) {
        if let existing = fetchTokenModel(linkageKey: linkageKey) {
            existing.tokenRaw = token.rawValue.uuidString
        } else {
            modelContext.insert(
                DiagnosticDataSchemaV1.DiagnosticTokenMapModel(
                    linkageKey: linkageKey,
                    token: token
                )
            )
        }
        save()
    }

    func removeToken(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) {
        guard let model = fetchTokenModel(linkageKey: linkageKey) else {
            return
        }
        modelContext.delete(model)
        save()
    }

    private func fetchTokenModel(
        linkageKey: DiagnosticIdentityLinkageKey
    ) -> DiagnosticDataSchemaV1.DiagnosticTokenMapModel? {
        let raw = linkageKey.rawValue
        var descriptor = FetchDescriptor<DiagnosticDataSchemaV1.DiagnosticTokenMapModel>(
            predicate: #Predicate { $0.linkageKeyRaw == raw }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            fatalError("SwiftData token fetch failed for Diagnostic Data: \(error)")
        }
    }

    private func save() {
        guard modelContext.hasChanges else {
            return
        }
        do {
            try modelContext.save()
        } catch {
            fatalError("SwiftData save failed for Diagnostic Data: \(error)")
        }
    }
}
