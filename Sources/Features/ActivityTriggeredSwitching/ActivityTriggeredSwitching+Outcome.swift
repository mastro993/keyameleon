import Foundation

extension ActivityTriggeredSwitching {
    func rebuildOutcome() {
        guard persistenceError == nil else { return }
        let previousLastActivePhysicalKeyboard = lastActivePhysicalKeyboard
        do {
            try rebuildOutcomeFromRecords()
        } catch {
            lastActivePhysicalKeyboard = previousLastActivePhysicalKeyboard
            markPersistenceUnavailable()
        }
    }
    private func rebuildOutcomeFromRecords() throws {
        let activeKeyboard = try activeKeyboardForOutcome()
        let currentIdentifier = observedCurrentInputSourceIdentifier
            ?? inputSources.currentInputSourceIdentifier
        let currentName = currentIdentifier.flatMap(displayName(forInputSourceIdentifier:))

        let assignment = activeKeyboard.map(assignmentCondition)
            ?? .none
        let wanted = currentWantedInputSource()
        let mismatch: ActivityTriggeredSwitchingMismatch? = {
            guard let wanted,
                  let currentIdentifier, currentIdentifier != wanted.inputSourceIdentifier,
                  let currentName = displayName(forInputSourceIdentifier: currentIdentifier),
                  let assignedName = displayName(forInputSourceIdentifier: wanted.inputSourceIdentifier)
            else { return nil }
            return ActivityTriggeredSwitchingMismatch(
                currentName: currentName,
                assignedName: assignedName,
                appName: appAssignments.frontmostAssignment == nil ? nil : appAssignments.frontmostApp?.name
            )
        }()

        let warnings = try switchingWarnings.sorted.map { warning in
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: try warningName(for: warning),
                category: warning.category,
                recoveryAction: warning.recoveryAction
            )
        }

        let availableActions = availableActions(warnings: warnings)
        let newOutcome = ActivityTriggeredSwitchingOutcome(
            switchingStatus: outcome.switchingStatus,
            temporarilyUnavailableReasons: outcome.temporarilyUnavailableReasons,
            activePhysicalKeyboard: activeKeyboard.map {
                ActivityTriggeredSwitchingActivePhysicalKeyboard(
                    name: $0.name,
                    connectionState: $0.connectionState,
                    assignment: assignmentCondition($0)
                )
            },
            currentKeyboardAssignment: assignment,
            currentInputSourceName: currentName,
            mismatch: mismatch,
            warnings: warnings,
            availableActions: availableActions,
            inputSourceHold: inputSourceHold.hold?.response,
            frontmostAppAssignment: appAssignments.outcome(eligibleInputSources: inputSources.eligibleInputSources)
        )
        guard newOutcome != outcome else {
            return
        }

        outcome = newOutcome
    }

    private func activeKeyboardForOutcome() throws -> PhysicalKeyboard? {
        if let activePhysicalKeyboardID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let connected = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activePhysicalKeyboardID
           }) {
            let resolved = try resolver.resolve(connected)
            lastActivePhysicalKeyboard = resolved
            return resolved
        }

        return lastActivePhysicalKeyboard?.asDisconnected()
    }

    private func assignmentCondition(
        _ physicalKeyboard: PhysicalKeyboard
    ) -> ActivityTriggeredSwitchingKeyboardAssignment {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            .unassigned
        case let .assigned(assignment):
            if isUnavailable(assignment) {
                .unavailable
            } else if let name = displayName(
                forInputSourceIdentifier: assignment.inputSourceIdentifier
            ) {
                .assigned(name: name)
            } else {
                .unavailable
            }
        case let .unsupported(reason):
            .unsupported(reason)
        }
    }

    private func warningName(for warning: SwitchingWarning) throws -> String? {
        if case let .unavailableAppAssignment(bundleIdentifier) = warning.cause {
            return appAssignments.assignments[bundleIdentifier]?.appName
        }
        if warning.cause == .selectionFailure, case let .app(_, name) = wantedInputSource?.origin {
            return name
        }
        guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause else {
            return try activeKeyboardForOutcome()?.name
        }

        if let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == physicalKeyboardID
        }) {
            return try resolver.resolve(keyboard).name
        }

        return try physicalKeyboardRecordStore.record(
            forIdentityKey: physicalKeyboardID.rawValue
        )?.name
    }

    private func displayName(forInputSourceIdentifier identifier: String) -> String? {
        inputSources.eligibleInputSources.first { $0.identifier == identifier }?.name
    }
}
