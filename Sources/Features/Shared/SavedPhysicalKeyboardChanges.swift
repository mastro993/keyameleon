@MainActor
final class SavedPhysicalKeyboardChanges {
    private let records: any PhysicalKeyboardRecordStoring
    private let session: SwiftDataPersistenceSession?
    private var pending: SavedPhysicalKeyboardChange?

    var hasPendingChange: Bool { pending != nil }

    init(records: SwiftDataPhysicalKeyboardRecordStore) {
        self.records = records
        session = records.session
    }

    init(records: InMemoryPhysicalKeyboardRecordStore) {
        self.records = records
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
        }
    }
}
