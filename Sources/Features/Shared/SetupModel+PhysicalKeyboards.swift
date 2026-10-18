import Foundation

extension SetupModel {
    func setPhysicalKeyboardName(
        _ physicalKeyboardID: PhysicalKeyboardRecordID,
        customName: String?
    ) {
        guard persistenceError == nil,
              activityTriggeredSwitching.persistenceError == nil,
              physicalKeyboardID.isIdentityBased else {
            return
        }

        let physicalKeyboard: PhysicalKeyboard
        if let liveKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }) {
            guard liveKeyboard.isAssignable else { return }
            physicalKeyboard = liveKeyboard
        } else {
            let records = savedPhysicalKeyboardRecords.filter { $0.recordID == physicalKeyboardID }
            guard records.count == 1,
                  let record = records.first,
                  !record.isBuiltInIdentity,
                  excludedPhysicalKeyboards.contains(where: {
                      $0.key == PhysicalKeyboardExclusionKey.key(for: physicalKeyboardID)
                  })
            else {
                return
            }
            physicalKeyboard = .restored(from: record)
        }

        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(
            .rename(keyboard: physicalKeyboard, customName: customName)
        ))
    }

    func setKeyboardAssignment(
        _ physicalKeyboardID: PhysicalKeyboardRecordID,
        inputSourceIdentifier: String?
    ) {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboard.isAssignable,
              physicalKeyboard.id.isIdentityBased
        else {
            return
        }

        let assignment = inputSourceIdentifier.flatMap(KeyboardAssignment.init)
        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(
            .assign(keyboard: physicalKeyboard, assignment: assignment)
        ))
    }

    func canExcludePhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        exclusionKey(for: physicalKeyboardID) != nil
    }

    func excludePhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard let key = exclusionKey(for: physicalKeyboardID),
              let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return
        }

        Log.debug(.setup, "Excluded \(physicalKeyboard.name) as a Physical Keyboard")
        lastKnownPhysicalKeyboards.removeValue(forKey: physicalKeyboardID.rawValue)
        activityTriggeredSwitching.forgetPhysicalKeyboard(physicalKeyboardID)
        exclusionStore.exclude(SavedPhysicalKeyboardExclusion(key: key, name: physicalKeyboard.name))
        applyExclusionKeysToDiscovery()
    }

    /// Key a person excludes this device by, or nil when it is not excludable.
    ///
    /// The built-in Physical Keyboard takes the nil branch. A connected device keys
    /// by its discovered facts, which is the only way to key a device without a
    /// Physical Keyboard Identity. A saved record keys by its own identity, so a
    /// disconnected Physical Keyboard stays excludable.
    func exclusionKey(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String? {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              !physicalKeyboard.isBuiltIn
        else {
            return nil
        }

        return physicalKeyboardDiscovery.exclusionKey(for: physicalKeyboardID)
            ?? (physicalKeyboardID.isIdentityBased
                ? PhysicalKeyboardExclusionKey.key(for: physicalKeyboardID)
                : nil)
    }

    func restorePhysicalKeyboard(exclusionKey: String) {
        guard excludedPhysicalKeyboards.contains(where: { $0.key == exclusionKey }) else {
            return
        }

        Log.debug(.setup, "Restored an excluded device to the Physical Keyboard list")
        exclusionStore.restore(key: exclusionKey)
        applyExclusionKeysToDiscovery()
    }

    func assignedInputSource(for physicalKeyboard: PhysicalKeyboard) -> EligibleInputSource? {
        guard let identifier = physicalKeyboard.keyboardAssignment?.inputSourceIdentifier else {
            return nil
        }

        return eligibleInputSources.first { $0.identifier == identifier }
    }

    func assignedInputSourceName(for physicalKeyboard: PhysicalKeyboard) -> String? {
        assignedInputSource(for: physicalKeyboard)?.name
    }

    func publishPhysicalKeyboards() {
        connectedExcludedKeyboardKeys = physicalKeyboardDiscovery.connectedExcludedKeys
        do {
            try readPhysicalKeyboards()
            if !savedPhysicalKeyboardChanges.hasPendingChange { persistenceError = nil }
        } catch {
            if !savedPhysicalKeyboardChanges.hasPendingChange {
                persistenceError = String(localized: .persistenceCheckDiskSpace)
            }
        }
    }

    private func readPhysicalKeyboards() throws {
        let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID
        let discovered = physicalKeyboardDiscovery.physicalKeyboards
        try migrateBuiltInRecordIfNeeded(from: discovered)
        let savedRecords = try physicalKeyboardRecordStore.allRecords()
        var knownKeyboards = lastKnownPhysicalKeyboards
        let connected = try discovered.map { keyboard in
            let published = try resolver.resolve(keyboard).markingActive(keyboard.id == activeID)
            if keyboard.id.isIdentityBased {
                knownKeyboards[keyboard.id.rawValue] = published.markingActive(false)
            }
            return published
        }

        excludedPhysicalKeyboards = exclusionStore.allExclusions()
        let excludedKeys = Set(excludedPhysicalKeyboards.map(\.key))

        let connectedIdentityKeys = Set(
            connected.filter(\.id.isIdentityBased).map(\.id.rawValue)
        )
        var disconnected = savedRecords
            .filter {
                !connectedIdentityKeys.contains($0.identityKey)
                    && !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: $0.recordID))
            }
            .map { savedRecord in
                PhysicalKeyboard
                    .restored(from: savedRecord)
                    .markingActive(savedRecord.recordID == activeID)
            }
        let disconnectedIdentityKeys = Set(disconnected.map(\.id.rawValue))

        if let activeID,
           activeID.isIdentityBased,
           !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: activeID)),
           !connectedIdentityKeys.contains(activeID.rawValue),
           !disconnectedIdentityKeys.contains(activeID.rawValue),
           let lastKnown = lastKnownPhysicalKeyboards[activeID.rawValue] {
            disconnected.append(lastKnown.asDisconnected().markingActive(true))
        }

        lastKnownPhysicalKeyboards = knownKeyboards
        savedPhysicalKeyboardRecords = savedRecords
        physicalKeyboards = PhysicalKeyboardListOrdering.sorted(
            connected + disconnected
        )
    }

    func applyExclusionKeysToDiscovery() {
        physicalKeyboardDiscovery.setExcludedKeys(
            Set(exclusionStore.allExclusions().map(\.key))
        )
    }

    private func migrateBuiltInRecordIfNeeded(
        from discovered: [PhysicalKeyboard]
    ) throws {
        guard !setupStore.hasEvaluatedBuiltInIdentityMigration,
              let builtIn = discovered.first(where: \.isBuiltIn)
        else {
            return
        }

        let migratedRecord = try physicalKeyboardRecordStore.migrateSingleOldBuiltInRecord(
            toIdentityKey: builtIn.id.rawValue,
            productName: builtIn.productName
        )
        setupStore.markBuiltInIdentityMigrationEvaluated()
        if migratedRecord != nil {
            Log.debug(
                .setup,
                "Migrated the saved record to the built-in Physical Keyboard"
            )
        }
    }

    func retryPersistenceOperation() {
        let result = savedPhysicalKeyboardChanges.retry()
        if case .nothingPending = result {
            publishPhysicalKeyboards()
        } else {
            finishSavedPhysicalKeyboardChange(result)
        }
        activityTriggeredSwitching.retryPersistenceRead()
    }

    private func finishSavedPhysicalKeyboardChange(_ result: SavedPhysicalKeyboardChangeResult) {
        switch result {
        case let .committed(change):
            persistenceError = nil
            switch change {
            case .rename:
                break
            case let .assign(keyboard, assignment):
                Log.debug(
                    .setup,
                    assignment == nil
                        ? "Keyboard Assignment removed for \(keyboard.name)"
                        : "Keyboard Assignment saved for \(keyboard.name)"
                )
                activityTriggeredSwitching.keyboardAssignmentDidChange(keyboard.id)
            }
            publishPhysicalKeyboards()
        case .failed:
            persistenceError = String(localized: .persistenceChangeNotSaved)
        case .blocked, .nothingPending:
            break
        }
    }
}
