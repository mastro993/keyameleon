import Testing
@testable import Keyameleon

private let alpha = PhysicalKeyboardRecordID(rawValue: "identity:alpha")
private let beta = PhysicalKeyboardRecordID(rawValue: "identity:beta")
private let us = "com.apple.keylayout.US"
private let italian = "com.apple.keylayout.Italian"

private func holdAfterChange(
    _ hold: InputSourceHold? = nil,
    response: ExternalChangeResponse,
    isReady: Bool = true,
    active: PhysicalKeyboardRecordID? = alpha,
    activeAssignment: String? = us,
    current: String? = italian
) -> InputSourceHold? {
    InputSourceHoldPolicy.holdAfterExternalChange(
        hold,
        response: response,
        isReady: isReady,
        activePhysicalKeyboardID: active,
        reachesWantedInputSource: current == (active == nil ? nil : activeAssignment)
    )
}

// MARK: - Hold start

@Test("Switch Back starts no Input Source Hold")
func policySwitchBackStartsNoHold() {
    #expect(holdAfterChange(response: .switchBack) == nil)
}

@Test("Hold Until Match starts a hold on an External Input Source Change")
func policyHoldUntilMatchStartsHold() {
    #expect(holdAfterChange(response: .holdUntilMatch) == .untilMatch)
}

@Test("Hold Until Keyboard Change holds by the Active Physical Keyboard")
func policyHoldUntilKeyboardChangeHoldsByActiveKeyboard() {
    #expect(
        holdAfterChange(response: .holdUntilKeyboardChange)
            == .untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    )
}

@Test("Without an Active Physical Keyboard the holding keyboard is not known yet")
func policyNoActiveKeyboardStartsHoldWithoutHoldingKeyboard() {
    #expect(
        holdAfterChange(response: .holdUntilKeyboardChange, active: nil, activeAssignment: nil)
            == .untilKeyboardChange(holdingPhysicalKeyboardID: nil)
    )
    #expect(holdAfterChange(response: .holdUntilMatch, active: nil, activeAssignment: nil) == .untilMatch)
}

@Test("An unassigned Active Physical Keyboard still lets a hold start")
func policyUnassignedActiveKeyboardStartsHold() {
    #expect(
        holdAfterChange(response: .holdUntilKeyboardChange, activeAssignment: nil)
            == .untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    )
}

@Test("No hold starts when the new Input Source equals the Active Physical Keyboard's Keyboard Assignment")
func policyNoHoldWhenNewInputSourceMatchesActiveAssignment() {
    for response in ExternalChangeResponse.allCases {
        #expect(holdAfterChange(response: response, current: us) == nil)
    }
}

@Test("No hold starts when Switching Status is not Ready")
func policyNoHoldWhenNotReady() {
    for response in ExternalChangeResponse.allCases {
        #expect(holdAfterChange(response: response, isReady: false) == nil)
    }
}

@Test("Another External Input Source Change during a hold does not restart it")
func policyAnotherChangeDoesNotRestartHold() {
    let hold = InputSourceHold.untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    #expect(holdAfterChange(hold, response: .holdUntilKeyboardChange, active: beta) == hold)
    #expect(holdAfterChange(hold, response: .holdUntilKeyboardChange, current: us) == hold)
    #expect(holdAfterChange(.untilMatch, response: .holdUntilMatch, current: "com.apple.keylayout.ABC") == .untilMatch)
}

// MARK: - Hold end on Activation Activity

private func holdAfterActivity(
    _ hold: InputSourceHold?,
    from keyboard: PhysicalKeyboardRecordID,
    assignment: String?,
    current: String? = italian
) -> InputSourceHold? {
    InputSourceHoldPolicy.holdAfterActivationActivity(
        hold,
        physicalKeyboardID: keyboard,
        wantedInputSourceIdentifier: assignment,
        currentInputSourceIdentifier: current
    )
}

@Test("Activation Activity without a hold keeps no hold")
func policyActivityWithoutHoldKeepsNoHold() {
    #expect(holdAfterActivity(nil, from: alpha, assignment: us) == nil)
}

@Test("Hold Until Match ends on a keyboard whose Keyboard Assignment equals the current Input Source")
func policyHoldUntilMatchEndsOnMatchingKeyboard() {
    #expect(holdAfterActivity(.untilMatch, from: beta, assignment: italian) == nil)
}

@Test("Hold Until Match continues on a keyboard with another or no Keyboard Assignment")
func policyHoldUntilMatchContinuesOnOtherKeyboards() {
    #expect(holdAfterActivity(.untilMatch, from: alpha, assignment: us) == .untilMatch)
    #expect(holdAfterActivity(.untilMatch, from: beta, assignment: nil) == .untilMatch)
    #expect(holdAfterActivity(.untilMatch, from: beta, assignment: nil, current: nil) == .untilMatch)
}

@Test("Hold Until Keyboard Change continues on the holding keyboard")
func policyHoldUntilKeyboardChangeContinuesOnHoldingKeyboard() {
    let hold = InputSourceHold.untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    #expect(holdAfterActivity(hold, from: alpha, assignment: us) == hold)
}

@Test("Hold Until Keyboard Change ends on another keyboard, assigned or not")
func policyHoldUntilKeyboardChangeEndsOnAnotherKeyboard() {
    let hold = InputSourceHold.untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    #expect(holdAfterActivity(hold, from: beta, assignment: us) == nil)
    #expect(holdAfterActivity(hold, from: beta, assignment: nil) == nil)
}

@Test("The first keyboard typed on becomes the holding keyboard")
func policyFirstKeyboardTypedOnBecomesHoldingKeyboard() {
    #expect(
        holdAfterActivity(.untilKeyboardChange(holdingPhysicalKeyboardID: nil), from: beta, assignment: us)
            == .untilKeyboardChange(holdingPhysicalKeyboardID: beta)
    )
}

// MARK: - Hold end on keyboard changes

@Test("Editing the holding keyboard's Keyboard Assignment ends Hold Until Keyboard Change")
func policyAssignmentChangeOfHoldingKeyboardEndsHold() {
    let hold = InputSourceHold.untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    #expect(InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        hold, physicalKeyboardID: alpha, activePhysicalKeyboardID: beta
    ))
    #expect(!InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        hold, physicalKeyboardID: beta, activePhysicalKeyboardID: beta
    ))
}

@Test("Editing the Active Physical Keyboard's Keyboard Assignment ends Hold Until Match")
func policyAssignmentChangeOfActiveKeyboardEndsHoldUntilMatch() {
    #expect(InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        .untilMatch, physicalKeyboardID: alpha, activePhysicalKeyboardID: alpha
    ))
    #expect(!InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        .untilMatch, physicalKeyboardID: beta, activePhysicalKeyboardID: alpha
    ))
}

@Test("Keyboard Assignment changes without a hold or holding keyboard end nothing")
func policyAssignmentChangeWithoutHoldingKeyboardEndsNothing() {
    #expect(!InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        nil, physicalKeyboardID: alpha, activePhysicalKeyboardID: alpha
    ))
    #expect(!InputSourceHoldPolicy.endsHoldOnKeyboardAssignmentChange(
        .untilKeyboardChange(holdingPhysicalKeyboardID: nil), physicalKeyboardID: alpha, activePhysicalKeyboardID: nil
    ))
}

@Test("Only the holding keyboard disconnecting ends Hold Until Keyboard Change")
func policyHoldingKeyboardDisconnectEndsHold() {
    let hold = InputSourceHold.untilKeyboardChange(holdingPhysicalKeyboardID: alpha)
    #expect(InputSourceHoldPolicy.endsHoldOnDisconnect(hold, physicalKeyboardID: alpha))
    #expect(!InputSourceHoldPolicy.endsHoldOnDisconnect(hold, physicalKeyboardID: beta))
    #expect(!InputSourceHoldPolicy.endsHoldOnDisconnect(
        .untilKeyboardChange(holdingPhysicalKeyboardID: nil), physicalKeyboardID: alpha
    ))
    #expect(!InputSourceHoldPolicy.endsHoldOnDisconnect(.untilMatch, physicalKeyboardID: alpha))
    #expect(!InputSourceHoldPolicy.endsHoldOnDisconnect(nil, physicalKeyboardID: alpha))
}
