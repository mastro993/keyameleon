import Foundation
@preconcurrency import SwiftData

@MainActor
protocol ManualPhysicalKeyboardDesignationStoring: AnyObject {
    func designation(forIdentityKey identityKey: String) -> SavedManualPhysicalKeyboardDesignation?
    func allDesignations() -> [SavedManualPhysicalKeyboardDesignation]
    func save(_ designation: SavedManualPhysicalKeyboardDesignation)
    func delete(identityKey: String)
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

    func save(_ designation: SavedManualPhysicalKeyboardDesignation) {
        designations[designation.identityKey] = designation
    }

    func delete(identityKey: String) {
        designations.removeValue(forKey: identityKey)
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
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func designation(forIdentityKey identityKey: String) -> SavedManualPhysicalKeyboardDesignation? {
        fetchModel(identityKey: identityKey)?.savedDesignation
    }

    func allDesignations() -> [SavedManualPhysicalKeyboardDesignation] {
        do {
            return try modelContext
                .fetch(
                    FetchDescriptor<
                        ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel
                    >()
                )
                .map(\.savedDesignation)
        } catch {
            fatalError("SwiftData fetch failed for Manual Physical Keyboard Designation: \(error)")
        }
    }

    func save(_ designation: SavedManualPhysicalKeyboardDesignation) {
        if let existing = fetchModel(identityKey: designation.identityKey) {
            existing.productName = designation.productName
            existing.confirmedName = designation.confirmedName
            existing.authenticationTag = designation.authenticationTag
        } else {
            modelContext.insert(
                ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel(
                    identityKey: designation.identityKey,
                    productName: designation.productName,
                    confirmedName: designation.confirmedName,
                    authenticationTag: designation.authenticationTag
                )
            )
        }
        persist()
    }

    func delete(identityKey: String) {
        guard let model = fetchModel(identityKey: identityKey) else {
            return
        }

        modelContext.delete(model)
        persist()
    }

    private func fetchModel(
        identityKey: String
    ) -> ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel? {
        var descriptor = FetchDescriptor<
            ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel
        >(
            predicate: #Predicate { $0.identityKey == identityKey }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            fatalError("SwiftData fetch failed for Manual Physical Keyboard Designation: \(error)")
        }
    }

    private func persist() {
        guard modelContext.hasChanges else {
            return
        }

        do {
            try modelContext.save()
        } catch {
            fatalError("SwiftData save failed for Manual Physical Keyboard Designation: \(error)")
        }
    }
}
