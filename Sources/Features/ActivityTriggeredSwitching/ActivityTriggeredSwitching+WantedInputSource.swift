import Foundation

extension ActivityTriggeredSwitching {
    func reconcileWantedAssignmentFromRecords(_ records: [SavedPhysicalKeyboardRecord]) {
        guard let physicalKeyboardID = wantedInputSource?.physicalKeyboardID else {
            return
        }

        reconcileWantedInputSource(with: records
            .first { $0.identityKey == physicalKeyboardID.rawValue }?
            .keyboardAssignment?.inputSourceIdentifier)
    }

    /// Follows an edit (a new Input Source) or removal (nil) of the assignment
    /// the Wanted Input Source came from.
    func reconcileWantedInputSource(with inputSourceIdentifier: String?) {
        guard let wanted = wantedInputSource else {
            return
        }

        guard let inputSourceIdentifier else {
            wantedInputSource = nil
            wantedInputSourceIdentifier = nil
            verifiedInputSourceIdentifier = nil
            switchingWarnings.clear(.selectionFailure)
            return
        }

        guard inputSourceIdentifier != wanted.inputSourceIdentifier else {
            return
        }

        wantedInputSource = WantedInputSource(origin: wanted.origin, inputSourceIdentifier: inputSourceIdentifier)
        wantedInputSourceIdentifier = inputSourceIdentifier
        if verifiedInputSourceIdentifier != inputSourceIdentifier {
            verifiedInputSourceIdentifier = nil
        }
        switchingWarnings.clear(.selectionFailure)
    }

    /// The Wanted Input Source for the Frontmost App and the Active Physical Keyboard.
    func currentWantedInputSource() -> WantedInputSource? {
        WantedInputSource.resolve(
            appAssignment: appAssignments.frontmostAssignment,
            activePhysicalKeyboard: lastActivePhysicalKeyboard
        )
    }

    /// Selects the Wanted Input Source unless it is unavailable or already verified and current.
    func applyWantedInputSource(_ wanted: WantedInputSource) {
        let wantedIdentifier = wanted.inputSourceIdentifier
        let currentIdentifier = inputSources.currentInputSourceIdentifier
        observedCurrentInputSourceIdentifier = currentIdentifier
        wantedInputSource = wanted

        if isUnavailable(wantedIdentifier) {
            switchingWarnings.clear(.selectionFailure)
            switchingWarnings.open(.unavailableAssignment(for: wanted))
            if verifiedInputSourceIdentifier == wantedIdentifier {
                verifiedInputSourceIdentifier = nil
            }
            wantedInputSourceIdentifier = wantedIdentifier
        } else if wantedInputSourceIdentifier == wantedIdentifier,
                  verifiedInputSourceIdentifier == wantedIdentifier,
                  currentIdentifier == wantedIdentifier {
            switchingWarnings.clear(.selectionFailure)
        } else {
            wantedInputSourceGeneration &+= 1
            let generation = wantedInputSourceGeneration
            wantedInputSourceIdentifier = wantedIdentifier
            _ = selectWantedInputSource(generation: generation)
        }
    }

    func selectWantedInputSource(generation: UInt64) -> Bool {
        guard persistenceError == nil, let wanted = wantedInputSource else {
            return false
        }
        let inputSourceIdentifier = wanted.inputSourceIdentifier
        let keyboardName = switch wanted.origin {
        case let .keyboard(physicalKeyboardID): physicalKeyboardName(physicalKeyboardID)
        case let .app(_, name): name
        }
        guard persistenceError == nil else { return false }
        let verified = inputSources.selectAndVerifyInputSource(identifier: inputSourceIdentifier)
        guard generation == wantedInputSourceGeneration else {
            return false
        }

        if verified {
            verifiedInputSourceIdentifier = inputSourceIdentifier
            observedCurrentInputSourceIdentifier = inputSourceIdentifier
            switchingWarnings.clear(.selectionFailure)
            Log.debug(
                .switching,
                "Selected Input Source \(inputSourceIdentifier) for "
                    + "\(keyboardName)"
            )
            return true
        }

        if verifiedInputSourceIdentifier == inputSourceIdentifier {
            verifiedInputSourceIdentifier = nil
        }
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        switchingWarnings.open(.selectionFailure(inputSourceIdentifier: inputSourceIdentifier))
        Log.warning(
            .switching,
            "Could not select Input Source \(inputSourceIdentifier) for "
                + "\(keyboardName)"
        )
        return false
    }

    func isUnavailable(_ assignment: KeyboardAssignment) -> Bool {
        isUnavailable(assignment.inputSourceIdentifier)
    }

    func isUnavailable(_ inputSourceIdentifier: String) -> Bool {
        !eligibleIdentifiers.contains(inputSourceIdentifier)
    }

    var eligibleIdentifiers: Set<String> {
        Set(inputSources.eligibleInputSources.map(\.identifier))
    }

    /// Opens or clears a warning for every saved Keyboard and App Assignment
    /// whose Input Source is unavailable. Returns whether a keyboard warning changed.
    @discardableResult
    func reevaluateUnavailableAssignments(records: [SavedPhysicalKeyboardRecord]? = nil) throws -> Bool {
        switchingWarnings.reevaluate(appAssignments, eligibleIdentifiers: eligibleIdentifiers)
        return switchingWarnings.reevaluateKeyboardAssignments(
            try records ?? physicalKeyboardRecordStore.allRecords(),
            eligibleIdentifiers: eligibleIdentifiers,
            excludedKeys: Set(exclusionStore.allExclusions().map(\.key))
        )
    }
}
