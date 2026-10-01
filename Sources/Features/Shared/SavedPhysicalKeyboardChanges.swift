@MainActor
final class SavedPhysicalKeyboardChanges {
    private let records: any PhysicalKeyboardRecordStoring
    private let designations: any ManualPhysicalKeyboardDesignationStoring
    private let session: SwiftDataPersistenceSession?
    private var pending: SavedPhysicalKeyboardChange?

    var hasPendingChange: Bool { pending != nil }

    init(
        records: SwiftDataPhysicalKeyboardRecordStore,
        designations: SwiftDataManualPhysicalKeyboardDesignationStore
    ) {
        precondition(records.session === designations.session, "Saved changes require one shared persistence session")
        self.records = records
        self.designations = designations
        session = records.session
    }

    init(
        records: InMemoryPhysicalKeyboardRecordStore,
        designations: InMemoryManualPhysicalKeyboardDesignationStore
    ) {
        self.records = records
        self.designations = designations
        session = nil
    }

    func perform(_ change: SavedPhysicalKeyboardChange) -> SavedPhysicalKeyboardChangeResult {
        guard pending == nil else { return .blocked }
        return execute(change)
    }

    func retry() -> SavedPhysicalKeyboardChangeResult {
        session?.retryOpening()
        guard let change = pending else { return .nothingPending }
        pending = nil
        return execute(change)
    }

    func cancelPendingDesignation() -> Bool {
        guard let pending, case .designate = pending else { return false }
        self.pending = nil
        return true
    }

    private func execute(_ change: SavedPhysicalKeyboardChange) -> SavedPhysicalKeyboardChangeResult {
        do {
            if let session {
                try session.transaction { try apply(change) }
            } else {
                try apply(change)
            }
            pending = nil
            return .committed(change)
        } catch {
            pending = change
            return .failed
        }
    }

    private func apply(_ change: SavedPhysicalKeyboardChange) throws {
        switch change {
        case let .rename(keyboard, customName):
            try records.saveName(
                identityKey: keyboard.id.rawValue,
                productName: keyboard.productName,
                customName: customName
            )
        case let .assign(keyboard, assignment):
            try records.saveAssignment(
                identityKey: keyboard.id.rawValue,
                productName: keyboard.productName,
                assignment: assignment
            )
        case let .replace(old, new):
            try records.transferRecord(
                fromIdentityKey: old.id.rawValue,
                toIdentityKey: new.id.rawValue,
                productName: new.productName
            )
            try designations.delete(identityKey: old.id.rawValue)
        case let .forget(keyboard):
            try records.deleteRecord(identityKey: keyboard.id.rawValue)
            try designations.delete(identityKey: keyboard.id.rawValue)
        case let .designate(designation):
            try designations.save(designation)
            try records.saveName(
                identityKey: designation.identityKey,
                productName: designation.productName,
                customName: designation.confirmedName
            )
        }
    }
}
