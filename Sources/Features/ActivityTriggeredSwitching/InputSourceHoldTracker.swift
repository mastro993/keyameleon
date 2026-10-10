import Foundation

/// The running Input Source Hold and its debug log lines.
///
/// Activity-Triggered Switching feeds it facts and `InputSourceHoldPolicy`
/// makes each decision. It lives in memory only, so an app restart ends any
/// hold. Log lines name Input Sources and Physical Keyboards, never Key Content.
struct InputSourceHoldTracker: Equatable {
    private(set) var hold: InputSourceHold?

    mutating func noteExternalChange(
        to currentInputSourceIdentifier: String?,
        response: ExternalChangeResponse,
        isReady: Bool,
        activePhysicalKeyboard: PhysicalKeyboard?
    ) {
        let wasHolding = hold != nil
        hold = InputSourceHoldPolicy.holdAfterExternalChange(
            hold,
            response: response,
            isReady: isReady,
            activePhysicalKeyboard: activePhysicalKeyboard.map {
                ($0.id, $0.keyboardAssignment?.inputSourceIdentifier)
            },
            currentInputSourceIdentifier: currentInputSourceIdentifier
        )
        if !wasHolding, let hold {
            Log.debug(
                .switching,
                "Input Source Hold started for \(currentInputSourceIdentifier ?? "none") (\(hold.response.rawValue))"
            )
        }
    }

    /// Whether the hold still keeps the current Input Source after Activation
    /// Activity from this Physical Keyboard. False means its Keyboard Assignment applies.
    mutating func keepsInputSource(
        afterActivationActivityFrom physicalKeyboard: PhysicalKeyboard,
        currentInputSourceIdentifier: String?
    ) -> Bool {
        guard hold != nil else {
            return false
        }

        hold = InputSourceHoldPolicy.holdAfterActivationActivity(
            hold,
            physicalKeyboardID: physicalKeyboard.id,
            assignmentIdentifier: physicalKeyboard.keyboardAssignment?.inputSourceIdentifier,
            currentInputSourceIdentifier: currentInputSourceIdentifier
        )
        guard hold == nil else {
            return true
        }

        Log.debug(.switching, "Input Source Hold ended (Activation Activity from \(physicalKeyboard.name))")
        return false
    }

    /// Ends the hold when editing or removing this Physical Keyboard's
    /// Keyboard Assignment ends it. Returns whether it ended.
    mutating func endOnKeyboardAssignmentChange(
        of physicalKeyboardID: PhysicalKeyboardRecordID,
        activePhysicalKeyboardID: PhysicalKeyboardRecordID?
    ) -> Bool {
        guard InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
            hold,
            physicalKeyboardID: physicalKeyboardID,
            activePhysicalKeyboardID: activePhysicalKeyboardID
        ) else {
            return false
        }

        return end(reason: "Keyboard Assignment changed")
    }

    /// Ends the hold when this Physical Keyboard is the holding one. Returns whether it ended.
    mutating func endOnDisconnect(of physicalKeyboardID: PhysicalKeyboardRecordID, name: String) -> Bool {
        guard InputSourceHoldPolicy.endsHoldOnDisconnect(hold, physicalKeyboardID: physicalKeyboardID) else {
            return false
        }

        return end(reason: "\(name) disconnected")
    }

    /// Ends any hold. Returns whether one was running.
    @discardableResult
    mutating func end(reason: String) -> Bool {
        guard hold != nil else {
            return false
        }

        hold = nil
        Log.debug(.switching, "Input Source Hold ended (\(reason))")
        return true
    }
}
