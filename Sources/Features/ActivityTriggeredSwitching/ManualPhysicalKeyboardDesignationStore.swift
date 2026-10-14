import Foundation
@preconcurrency import SwiftData

@MainActor
protocol ManualPhysicalKeyboardDesignationStoring: AnyObject {
    func designation(forIdentityKey identityKey: String) throws -> SavedManualPhysicalKeyboardDesignation?
    func allDesignations() throws -> [SavedManualPhysicalKeyboardDesignation]
}

@MainActor
final class InMemoryManualPhysicalKeyboardDesignationStore: ManualPhysicalKeyboardDesignationStoring {
    private var designations: [String: SavedManualPhysicalKeyboardDesignation] = [:]

    func designation(forIdentityKey identityKey: String) -> SavedManualPhysicalKeyboardDesignation? {
        designations[identityKey]
    }

    func allDesignations() -> [SavedManualPhysicalKeyboardDesignation] {
        Array(designations.values)
    }

    /// Seeds a designation saved by an earlier version. Keyameleon no longer creates designations.
    func save(_ designation: SavedManualPhysicalKeyboardDesignation) {
        designations[designation.identityKey] = designation
    }
}

enum ManualPhysicalKeyboardDesignationSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [ManualPhysicalKeyboardDesignationModel.self]
    }

    @Model
    final class ManualPhysicalKeyboardDesignationModel {
        @Attribute(.unique) var identityKey: String
        var productName: String
        var confirmedName: String
        var authenticationTag: Data

        init(
            identityKey: String,
            productName: String,
            confirmedName: String,
            authenticationTag: Data
        ) {
            self.identityKey = identityKey
            self.productName = productName
            self.confirmedName = confirmedName
            self.authenticationTag = authenticationTag
        }

        var savedDesignation: SavedManualPhysicalKeyboardDesignation {
            SavedManualPhysicalKeyboardDesignation(
                identityKey: identityKey,
                productName: productName,
                confirmedName: confirmedName,
                authenticationTag: authenticationTag
            )
        }
    }
}

@MainActor
final class SwiftDataManualPhysicalKeyboardDesignationStore: ManualPhysicalKeyboardDesignationStoring {
    let session: SwiftDataPersistenceSession

    init(modelContext: ModelContext) {
        session = SwiftDataPersistenceSession(modelContext: modelContext)
    }

    init(session: SwiftDataPersistenceSession) {
        self.session = session
    }

    func designation(forIdentityKey identityKey: String) throws -> SavedManualPhysicalKeyboardDesignation? {
        try fetchModel(identityKey: identityKey)?.savedDesignation
    }

    func allDesignations() throws -> [SavedManualPhysicalKeyboardDesignation] {
        try session.fetch(
            FetchDescriptor<ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel>()
        )
            .map(\.savedDesignation)
    }

    private func fetchModel(
        identityKey: String
    ) throws -> ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel? {
        var descriptor = FetchDescriptor<
            ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel
        >(
            predicate: #Predicate { $0.identityKey == identityKey }
        )
        descriptor.fetchLimit = 1

        return try session.fetch(descriptor).first
    }
}
