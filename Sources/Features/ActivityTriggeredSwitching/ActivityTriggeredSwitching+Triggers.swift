import Foundation

extension ActivityTriggeredSwitching {
    /// Internal seam for deterministic module tests.
    func handleActivationActivity(_ activity: PhysicalKeyboardActivationActivity) {
        guard acceptsTrigger(), let rawKeyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == activity.physicalKeyboardID
        }) else {
            return
        }

        inputSources.refreshCurrentIdentifier()
        let physicalKeyboard: PhysicalKeyboard
        do {
            physicalKeyboard = try resolver.resolve(rawKeyboard)
        } catch {
            markPersistenceUnavailable()
            return
        }
        let activeChanged = physicalKeyboardDiscovery.activePhysicalKeyboardID != physicalKeyboard.id
        lastActivePhysicalKeyboard = physicalKeyboard
        physicalKeyboardDiscovery.markActive(physicalKeyboard.id)

        if activeChanged {
            Log.debug(
                .switching,
                "Active Physical Keyboard is now \(physicalKeyboard.name)"
            )
        }

        let wanted = currentWantedInputSource()
        if inputSourceHold.keepsInputSource(
            afterActivationActivityFrom: physicalKeyboard,
            wantedInputSourceIdentifier: wanted?.inputSourceIdentifier,
            currentInputSourceIdentifier: inputSources.currentInputSourceIdentifier
        ) {
            rebuildOutcome()
            return
        }

        if let wanted {
            applyWantedInputSource(wanted)
        }

        rebuildOutcome()
    }

    /// Internal seam for deterministic App Activations. Keyameleon's own
    /// activation is not one, so the Frontmost App stays the previous app.
    func handleAppActivation(_ app: FrontmostApp) {
        guard appAssignments.noteActivation(of: app) else { return }
        // The Frontmost App shows in the outcome even when nothing is selected.
        guard acceptsTrigger() else { return rebuildOutcome() }

        // A change still pending ends with this hold instead of starting a new one.
        inputSources.refreshCurrentIdentifier()
        inputSourceHold.end(reason: "App Activation")
        if let wanted = currentWantedInputSource() {
            applyWantedInputSource(wanted)
        }
        rebuildOutcome()
    }

    /// Whether Activation Activity or an App Activation may select an Input
    /// Source now. Secure Input or unavailable protected data rechecks status instead.
    private func acceptsTrigger() -> Bool {
        guard isStarted, appliesKeyboardAssignments, persistenceError == nil,
              outcome.switchingStatus == .ready else {
            return false
        }

        let protectedState = protectedStateProvider.currentProtectedState()
        if protectedState.isSecureInputEnabled || !protectedState.isProtectedDataAvailable {
            checkAgain()
            return false
        }
        return true
    }

    /// Internal seam for deterministic external Input Source changes.
    func handleExternalInputSourceChange() {
        guard isStarted, persistenceError == nil, outcome.switchingStatus == .ready else {
            return
        }
        let currentIdentifier = inputSources.currentInputSourceIdentifier
        let previousObserved = observedCurrentInputSourceIdentifier
        let previousVerified = verifiedInputSourceIdentifier
        let previousHold = inputSourceHold
        observedCurrentInputSourceIdentifier = currentIdentifier

        if let verified = verifiedInputSourceIdentifier,
           currentIdentifier != verified {
            verifiedInputSourceIdentifier = nil
        }

        // Keyameleon's own selections update the observed Input Source before their
        // notification arrives, so only an External Input Source Change gets here.
        if currentIdentifier != previousObserved {
            inputSourceHold.noteExternalChange(
                to: currentIdentifier,
                response: externalChangeResponse,
                isReady: appliesKeyboardAssignments,
                activePhysicalKeyboardID: lastActivePhysicalKeyboard?.id,
                wantedInputSourceIdentifier: currentWantedInputSource()?.inputSourceIdentifier
            )
        }

        if previousObserved != observedCurrentInputSourceIdentifier
            || previousVerified != verifiedInputSourceIdentifier
            || previousHold != inputSourceHold {
            Log.verbose(
                .switching,
                "Observed Input Source is now \(observedCurrentInputSourceIdentifier ?? "none")"
            )
            rebuildOutcome()
        }
    }
}
