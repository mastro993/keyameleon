struct OnboardingPhysicalKeyboardRow: Identifiable, Equatable {
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

struct OnboardingPhysicalKeyboardRows: Equatable {
    private(set) var rows: [OnboardingPhysicalKeyboardRow] = []

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
        var reconciledRows: [OnboardingPhysicalKeyboardRow] = []

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
    ) -> [OnboardingPhysicalKeyboardRow] {
        candidates.compactMap { candidate in
            guard !consumedKeyboardIDs.contains(candidate.keyboard.id),
                  candidate.exclusionKey.flatMap({ exclusionsByKey[$0] }) == nil
            else {
                return nil
            }

            return OnboardingPhysicalKeyboardRow(
                physicalKeyboard: candidate.keyboard,
                exclusionKey: candidate.exclusionKey
            )
        }
    }

    private func missingExclusionRows(
        _ exclusions: [SavedPhysicalKeyboardExclusion],
        from rows: [OnboardingPhysicalKeyboardRow],
        savedRecords: [SavedPhysicalKeyboardRecord]
    ) -> [OnboardingPhysicalKeyboardRow] {
        exclusions.compactMap { exclusion in
            guard !rows.contains(where: { $0.exclusionKey == exclusion.key }) else {
                return nil
            }
            return OnboardingPhysicalKeyboardRow(
                exclusion: exclusion,
                savedRecord: savedRecordSelection(for: exclusion.key, anchoredTo: nil, in: savedRecords)
            )
        }
    }

    private func savedRecordSelection(
        for exclusionKey: String,
        anchoredTo keyboardID: PhysicalKeyboardRecordID?,
        in savedRecords: [SavedPhysicalKeyboardRecord]
    ) -> OnboardingPhysicalKeyboardRow.SavedRecordSelection {
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
