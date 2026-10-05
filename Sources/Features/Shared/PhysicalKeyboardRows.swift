import Foundation

/// One row of a Physical Keyboard list, shared by Guided setup and Settings.
///
/// A row keeps its identity while the keyboard it shows connects, disconnects,
/// gets renamed, or is ignored, so neither flow reorders under the person's
/// hands. Included and ignored keyboards take the same row.
struct PhysicalKeyboardRow: Identifiable, Equatable {
    enum SavedRecordSelection: Equatable {
        case matched(SavedPhysicalKeyboardRecord)
        case missing
        case ambiguous
    }

    enum RowID: Hashable {
        case keyboard(PhysicalKeyboardRecordID)
        case exclusion(String)
    }

    enum State: Equatable {
        case included(PhysicalKeyboard)
        case excluded(SavedPhysicalKeyboardExclusion, SavedRecordSelection)
    }

    let id: RowID
    var exclusionKey: String?
    var state: State

    func subtitle(connectedExcludedKeys: Set<String>) -> String {
        let productName: String?
        let isConnected: Bool
        switch state {
        case let .included(keyboard):
            productName = keyboard.customName == nil ? nil : keyboard.productName
            isConnected = keyboard.connectionState == .connected
        case let .excluded(exclusion, savedRecord):
            if case let .matched(record) = savedRecord, record.customName != nil {
                productName = record.productName
            } else {
                productName = nil
            }
            isConnected = connectedExcludedKeys.contains(exclusion.key)
        }
        var status = isConnected ? "Connected" : "Disconnected"
        if case .excluded = state {
            status += " (Ignored)"
        }
        return productName.map { "\($0) - \(status)" } ?? status
    }

    var physicalKeyboardID: PhysicalKeyboardRecordID? {
        if case let .keyboard(id) = id {
            return id
        }
        if case let .included(keyboard) = state {
            return keyboard.id
        }
        return nil
    }

    init(physicalKeyboard: PhysicalKeyboard, exclusionKey: String?) {
        id = .keyboard(physicalKeyboard.id)
        self.exclusionKey = exclusionKey
        state = .included(physicalKeyboard)
    }

    init(exclusion: SavedPhysicalKeyboardExclusion, savedRecord: SavedRecordSelection = .missing) {
        id = .exclusion(exclusion.key)
        exclusionKey = exclusion.key
        state = .excluded(exclusion, savedRecord)
    }
}

/// The reconciled Physical Keyboard rows one list draws.
struct PhysicalKeyboardRows: Equatable {
    private(set) var rows: [PhysicalKeyboardRow] = []

    @MainActor
    init(
        physicalKeyboards: [PhysicalKeyboard] = [],
        exclusions: [SavedPhysicalKeyboardExclusion] = [],
        savedRecords: [SavedPhysicalKeyboardRecord] = [],
        exclusionKeyFor: @MainActor (PhysicalKeyboardRecordID) -> String?
    ) {
        reconcile(
            physicalKeyboards: physicalKeyboards,
            exclusions: exclusions,
            savedRecords: savedRecords,
            exclusionKeyFor: exclusionKeyFor
        )
    }

    /// Reconciles against the setup model's current Physical Keyboard state.
    @MainActor
    mutating func reconcile(with model: SetupModel) {
        reconcile(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            savedRecords: model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: model.exclusionKey(for:)
        )
    }

    @MainActor
    mutating func reconcile(
        physicalKeyboards: [PhysicalKeyboard],
        exclusions: [SavedPhysicalKeyboardExclusion],
        savedRecords: [SavedPhysicalKeyboardRecord] = [],
        exclusionKeyFor: @MainActor (PhysicalKeyboardRecordID) -> String?
    ) {
        let current = PhysicalKeyboardListOrdering.sorted(physicalKeyboards).map { keyboard in
            (keyboard: keyboard, exclusionKey: exclusionKeyFor(keyboard.id))
        }
        let exclusionsByKey = Dictionary(
            exclusions.map { ($0.key, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var consumedKeyboardIDs: Set<PhysicalKeyboardRecordID> = []
        var reconciledRows: [PhysicalKeyboardRow] = []

        for var row in rows {
            if let key = row.exclusionKey, let exclusion = exclusionsByKey[key] {
                row.state = .excluded(exclusion, savedRecordSelection(
                    for: key, anchoredTo: row.physicalKeyboardID, in: savedRecords
                ))
                reconciledRows.append(row)
                continue
            }

            let matchingIndex = current.firstIndex { candidate in
                candidate.keyboard.id == row.physicalKeyboardID
                    && !consumedKeyboardIDs.contains(candidate.keyboard.id)
            } ?? current.firstIndex { candidate in
                guard let key = row.exclusionKey else {
                    return false
                }
                return candidate.exclusionKey == key
                    && !consumedKeyboardIDs.contains(candidate.keyboard.id)
            }

            guard let matchingIndex else {
                continue
            }

            let matchingKeyboard = current[matchingIndex]
            consumedKeyboardIDs.insert(matchingKeyboard.keyboard.id)
            row.exclusionKey = matchingKeyboard.exclusionKey
            row.state = .included(matchingKeyboard.keyboard)
            reconciledRows.append(row)
        }

        reconciledRows += newKeyboardRows(
            from: current,
            exclusionsByKey: exclusionsByKey,
            consumedKeyboardIDs: consumedKeyboardIDs
        )
        reconciledRows += missingExclusionRows(exclusions, from: reconciledRows, savedRecords: savedRecords)
        rows = reconciledRows
    }

    private func newKeyboardRows(
        from candidates: [(keyboard: PhysicalKeyboard, exclusionKey: String?)],
        exclusionsByKey: [String: SavedPhysicalKeyboardExclusion],
        consumedKeyboardIDs: Set<PhysicalKeyboardRecordID>
    ) -> [PhysicalKeyboardRow] {
        candidates.compactMap { candidate in
            guard !consumedKeyboardIDs.contains(candidate.keyboard.id),
                  candidate.exclusionKey.flatMap({ exclusionsByKey[$0] }) == nil
            else {
                return nil
            }

            return PhysicalKeyboardRow(
                physicalKeyboard: candidate.keyboard,
                exclusionKey: candidate.exclusionKey
            )
        }
    }

    private func missingExclusionRows(
        _ exclusions: [SavedPhysicalKeyboardExclusion],
        from rows: [PhysicalKeyboardRow],
        savedRecords: [SavedPhysicalKeyboardRecord]
    ) -> [PhysicalKeyboardRow] {
        exclusions.compactMap { exclusion in
            guard !rows.contains(where: { $0.exclusionKey == exclusion.key }) else {
                return nil
            }
            return PhysicalKeyboardRow(
                exclusion: exclusion,
                savedRecord: savedRecordSelection(for: exclusion.key, anchoredTo: nil, in: savedRecords)
            )
        }
    }

    private func savedRecordSelection(
        for exclusionKey: String,
        anchoredTo keyboardID: PhysicalKeyboardRecordID?,
        in savedRecords: [SavedPhysicalKeyboardRecord]
    ) -> PhysicalKeyboardRow.SavedRecordSelection {
        let matches = savedRecords.filter {
            PhysicalKeyboardExclusionKey.key(for: $0.recordID) == exclusionKey
        }
        if let keyboardID, let exact = matches.first(where: { $0.recordID == keyboardID }) {
            return .matched(exact)
        }
        switch matches.count {
        case 0: return .missing
        case 1: return .matched(matches[0])
        default: return .ambiguous
        }
    }
}
