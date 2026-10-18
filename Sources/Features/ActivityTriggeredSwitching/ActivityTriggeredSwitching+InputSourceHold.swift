import Foundation

extension ActivityTriggeredSwitching {
    /// Saves the External Change Response. Changing it ends any Input Source Hold.
    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        guard response != externalChangeResponse else {
            return
        }

        setupStore.setExternalChangeResponse(response)
        externalChangeResponse = response
        Log.debug(.switching, "External Change Response is now \(response.rawValue)")
        inputSourceHold.end(reason: "External Change Response changed")
        rebuildOutcome()
    }

    /// Ends the Input Source Hold and applies the Wanted Input Source.
    func switchBackNow() {
        guard inputSourceHold.hold != nil else {
            return
        }

        // A change still pending joins this hold instead of starting a new one.
        inputSources.refreshCurrentIdentifier()
        inputSourceHold.end(reason: "Switch Back Now")
        if persistenceError == nil, outcome.switchingStatus == .ready,
           let wanted = currentWantedInputSource() {
            applyWantedInputSource(wanted)
        }
        rebuildOutcome()
    }

    /// Setup seam: the person edited or removed one Physical Keyboard's Keyboard Assignment.
    func keyboardAssignmentDidChange(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID
        if inputSourceHold.endOnKeyboardAssignmentChange(of: physicalKeyboardID, activePhysicalKeyboardID: activeID) {
            rebuildOutcome()
        }
    }
}
