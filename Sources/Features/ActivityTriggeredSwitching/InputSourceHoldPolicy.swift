import Foundation

/// Decides when an Input Source Hold starts and ends.
///
/// Activity-Triggered Switching owns the hold and its effects; this policy owns
/// the rules that depend on Physical Keyboards and Input Sources. Pause,
/// Resume, a changed External Change Response, and Switch Back Now end any
/// hold unconditionally, so they need no rule here.
enum InputSourceHoldPolicy {
    /// The hold after an External Input Source Change.
    ///
    /// A running hold is kept as is: another change does not restart it.
    /// `activePhysicalKeyboard` carries the Active Physical Keyboard and its
    /// Keyboard Assignment's Input Source, if any.
    static func holdAfterExternalChange(
        _ hold: InputSourceHold?,
        response: ExternalChangeResponse,
        isReady: Bool,
        activePhysicalKeyboard: (id: PhysicalKeyboardRecordID, assignmentIdentifier: String?)?,
        currentInputSourceIdentifier: String?
    ) -> InputSourceHold? {
        if let hold { return hold }
        guard isReady, currentInputSourceIdentifier != activePhysicalKeyboard?.assignmentIdentifier else {
            return nil
        }

        switch response {
        case .switchBack:
            return nil
        case .holdUntilMatch:
            return .untilMatch
        case .holdUntilKeyboardChange:
            return .untilKeyboardChange(holdingPhysicalKeyboardID: activePhysicalKeyboard?.id)
        }
    }

    /// The hold after Activation Activity from one Physical Keyboard. Nil ends
    /// the hold, so that Physical Keyboard's Keyboard Assignment applies.
    static func holdAfterActivationActivity(
        _ hold: InputSourceHold?,
        physicalKeyboardID: PhysicalKeyboardRecordID,
        assignmentIdentifier: String?,
        currentInputSourceIdentifier: String?
    ) -> InputSourceHold? {
        switch hold {
        case nil:
            return nil
        case .untilMatch:
            guard let assignmentIdentifier, assignmentIdentifier == currentInputSourceIdentifier else {
                return hold
            }
            return nil
        case .untilKeyboardChange(holdingPhysicalKeyboardID: nil):
            return .untilKeyboardChange(holdingPhysicalKeyboardID: physicalKeyboardID)
        case let .untilKeyboardChange(holdingPhysicalKeyboardID?):
            return holdingPhysicalKeyboardID == physicalKeyboardID ? hold : nil
        }
    }

    /// Whether editing or removing one Physical Keyboard's Keyboard Assignment
    /// ends the hold. Hold Until Match is held by the Active Physical Keyboard.
    static func endsHoldOnKeyboardAssignmentChange(
        _ hold: InputSourceHold?,
        physicalKeyboardID: PhysicalKeyboardRecordID,
        activePhysicalKeyboardID: PhysicalKeyboardRecordID?
    ) -> Bool {
        switch hold {
        case nil:
            false
        case .untilMatch:
            physicalKeyboardID == activePhysicalKeyboardID
        case let .untilKeyboardChange(holdingPhysicalKeyboardID):
            physicalKeyboardID == holdingPhysicalKeyboardID
        }
    }

    /// Whether one Physical Keyboard disconnecting ends the hold. Only the
    /// holding Physical Keyboard of Hold Until Keyboard Change does.
    static func endsHoldOnDisconnect(
        _ hold: InputSourceHold?,
        physicalKeyboardID: PhysicalKeyboardRecordID
    ) -> Bool {
        guard case let .untilKeyboardChange(holdingPhysicalKeyboardID?) = hold else { return false }
        return holdingPhysicalKeyboardID == physicalKeyboardID
    }
}
