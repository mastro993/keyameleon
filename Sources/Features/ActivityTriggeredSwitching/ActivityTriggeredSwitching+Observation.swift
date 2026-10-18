import Foundation

extension ActivityTriggeredSwitching {
    func updateObservation(for status: SwitchingStatus) {
        updatePermissionWatch(for: status)
        guard isStarted else {
            return
        }

        if status.allowsPhysicalKeyboardDiscovery {
            physicalKeyboardDiscovery.start()
        } else {
            physicalKeyboardDiscovery.stop()
        }

        if status == .ready, persistenceError == nil {
            physicalKeyboardDiscovery.startActivationActivityObservation { [weak self] activity in
                self?.handleActivationActivity(activity)
            }
            inputSources.startObservingChanges()
        } else {
            physicalKeyboardDiscovery.stopActivationActivityObservation()
            inputSources.stopObservingChanges()
        }
    }

    func handleDiscoveryChange() {
        guard persistenceError == nil else {
            return
        }
        if let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activeID
           }) {
            do {
                lastActivePhysicalKeyboard = try resolver.resolve(keyboard)
            } catch {
                markPersistenceUnavailable()
                return
            }
        }
        do {
            try reevaluateUnavailableAssignments()
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    func handleDiscoveryRecordChange(
        _ change: PhysicalKeyboardDiscoveryRecordChange
    ) {
        switch change {
        case let .connected(physicalKeyboardID, name):
            let displayName = physicalKeyboardName(physicalKeyboardID, fallback: name)
            Log.debug(.switching, "Physical Keyboard connected (\(displayName))")
        case let .disconnected(physicalKeyboardID, name):
            let displayName = physicalKeyboardName(physicalKeyboardID, fallback: name)
            Log.debug(.switching, "Physical Keyboard disconnected (\(displayName))")
            if inputSourceHold.endOnDisconnect(of: physicalKeyboardID, name: displayName) {
                rebuildOutcome()
            }
        }
    }

    /// The name the panel shows, so a log line names the same Physical Keyboard
    /// the user sees. Catalog entries carry no custom name, and a disconnected
    /// Physical Keyboard is gone from the catalog, so the saved record comes
    /// first and the discovery payload is the last resort.
    func physicalKeyboardName(
        _ physicalKeyboardID: PhysicalKeyboardRecordID?,
        fallback: String? = nil
    ) -> String {
        guard let physicalKeyboardID else {
            return fallback ?? "name unknown"
        }
        do {
            if let savedName = try physicalKeyboardRecordStore
                .record(forIdentityKey: physicalKeyboardID.rawValue)?
                .name {
                return savedName
            }
        } catch {
            markPersistenceUnavailable()
        }
        if let catalogName = physicalKeyboardDiscovery.physicalKeyboards
            .first(where: { $0.id == physicalKeyboardID })?
            .name {
            return catalogName
        }
        return fallback ?? "name unknown"
    }

    func handleInputSourceModuleChange() {
        guard persistenceError == nil else {
            return
        }
        handleExternalInputSourceChange()
        guard persistenceError == nil else {
            return
        }
        do {
            try reevaluateUnavailableAssignments()
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    func handleRecordChange() {
        guard persistenceError == nil else {
            return
        }
        do {
            let records = try physicalKeyboardRecordStore.allRecords()
            reconcileWantedAssignmentFromRecords(records)
            try reevaluateUnavailableAssignments(records: records)
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }
}
