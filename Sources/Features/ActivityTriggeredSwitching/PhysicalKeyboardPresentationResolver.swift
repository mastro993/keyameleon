import Foundation

@MainActor
final class PhysicalKeyboardPresentationResolver {
    private let recordStore: any PhysicalKeyboardRecordStoring
    private let designationStore: any ManualPhysicalKeyboardDesignationStoring
    private let integrityKeyProvider: any InstallationIntegrityKeyProviding

    init(
        recordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding
    ) {
        self.recordStore = recordStore
        self.designationStore = designationStore
        self.integrityKeyProvider = integrityKeyProvider
    }

    func resolve(_ keyboard: PhysicalKeyboard) throws -> PhysicalKeyboard {
        guard keyboard.id.isIdentityBased else {
            return keyboard
        }

        let savedRecord = try recordStore.record(forIdentityKey: keyboard.id.rawValue)

        if keyboard.isAssignable {
            return keyboard.applying(savedRecord: savedRecord)
        }

        guard
            let designation = try designationStore.designation(
                forIdentityKey: keyboard.id.rawValue
            ),
            ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(
                designation,
                integrityKey: integrityKeyProvider.integrityKey()
            )
        else {
            return keyboard
        }

        return keyboard
            .elevatingWithManualDesignation(confirmedName: designation.confirmedName)
            .applying(savedRecord: savedRecord)
    }

    func verifyPersistenceRead() throws {
        _ = try recordStore.allRecords()
        _ = try designationStore.allDesignations()
    }
}
