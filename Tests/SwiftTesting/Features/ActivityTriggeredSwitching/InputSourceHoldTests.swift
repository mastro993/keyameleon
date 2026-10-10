import Testing
@testable import Keyameleon

private let us = "com.example.us"
private let italian = "com.example.italian"
private let other = "com.example.other"
private let alphaServiceID: UInt64 = 901
private let betaServiceID: UInt64 = 902

/// Two connected Physical Keyboards: alpha assigned to U.S., beta assigned as
/// each test needs. The module is Ready and Guided setup is complete.
@MainActor
private struct HoldFixture {
    let model: SetupModel
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector: SetupModelTestInputSourceSelector
    let changeObserver = SetupModelTestInputSourceChangeObserver()
    let setupStore = SetupModelTestSetupDecisionStore()
    let alphaID: PhysicalKeyboardRecordID
    let betaID: PhysicalKeyboardRecordID

    var switching: ActivityTriggeredSwitching {
        model.activityTriggeredSwitching
    }

    init(
        response: ExternalChangeResponse,
        betaAssignment: String? = other,
        current: String = other
    ) throws {
        selector = SetupModelTestInputSourceSelector(current: current)
        model = SetupModel(
            permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
            setupStore: setupStore,
            inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
            physicalKeyboardDiscoverer: discoverer,
            inputSourceProvider: SetupModelTestInputSourceProvider(
                inputSources: [
                    EligibleInputSource(identifier: us, name: "U.S."),
                    EligibleInputSource(identifier: italian, name: "Italian"),
                    EligibleInputSource(identifier: other, name: "Other"),
                ]
            ),
            inputSourceSelector: selector,
            inputSourceChangeObserver: changeObserver
        )
        startAndCheck(model)
        discoverer.emit(.connected(makeSetupModelHardwareFacts(
            serviceID: alphaServiceID,
            identity: "macos.keyboard.alpha",
            serialNumber: "serial-alpha"
        )))
        discoverer.emit(.connected(makeSetupModelHardwareFacts(
            serviceID: betaServiceID,
            identity: "macos.keyboard.beta",
            serialNumber: "serial-beta"
        )))
        alphaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }?.id)
        betaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("beta") }?.id)
        model.setKeyboardAssignment(alphaID, inputSourceIdentifier: us)
        if let betaAssignment {
            model.setKeyboardAssignment(betaID, inputSourceIdentifier: betaAssignment)
        }
        switching.setExternalChangeResponse(response)
    }

    func press(_ serviceID: UInt64) {
        switching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(serviceID: serviceID, kind: .press)
        )
    }

    /// Someone other than Keyameleon selects an Input Source.
    func changeExternally(to identifier: String) {
        selector.current = identifier
        changeObserver.emit()
    }

    /// Types on alpha, so it is active on U.S., then changes to Italian outside Keyameleon.
    func holdItalianAfterTypingOnAlpha() {
        press(alphaServiceID)
        changeExternally(to: italian)
    }
}

@Test("Switch Back is the default and the next Activation Activity applies the Keyboard Assignment")
@MainActor
func switchBackIsDefaultAndAppliesNextActivity() throws {
    #expect(SetupModelTestSetupDecisionStore().externalChangeResponse == .switchBack)
    let fixture = try HoldFixture(response: .switchBack)
    fixture.holdItalianAfterTypingOnAlpha()

    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.switching.outcome.inputSourceHold == nil)

    fixture.press(alphaServiceID)
    #expect(fixture.selector.requestedIdentifiers == [us, us])
}

@Test("Keyameleon's own selection is not an External Input Source Change")
@MainActor
func ownSelectionStartsNoHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.press(alphaServiceID)
    #expect(fixture.selector.requestedIdentifiers == [us])

    // The selection's own notification arrives after the readback.
    fixture.changeObserver.emit()
    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("Hold Until Keyboard Change keeps the Input Source while typing on the holding keyboard")
@MainActor
func holdUntilKeyboardChangeKeepsInputSourceOnHoldingKeyboard() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.alphaID))
    #expect(fixture.switching.outcome.inputSourceHold == .holdUntilKeyboardChange)

    fixture.press(alphaServiceID)
    fixture.press(alphaServiceID)
    #expect(fixture.selector.requestedIdentifiers == [us])
    #expect(fixture.selector.current == italian)
}

@Test("Hold Until Keyboard Change ends on another keyboard and applies its Keyboard Assignment")
@MainActor
func holdUntilKeyboardChangeEndsOnAnotherKeyboard() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.selector.requestedIdentifiers == [us, other])
}

@Test("An unassigned keyboard ends the hold and selects nothing; the original keyboard switches back")
@MainActor
func unassignedKeyboardEndsHoldWithoutSelecting() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange, betaAssignment: nil)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.selector.requestedIdentifiers == [us])

    fixture.press(alphaServiceID)
    #expect(fixture.selector.requestedIdentifiers == [us, us])
}

@Test("Before any typing, the first keyboard typed on becomes the holding keyboard")
@MainActor
func firstKeyboardTypedOnAfterLaunchHoldsTheInputSource() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.changeExternally(to: italian)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: nil))

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.betaID))
    #expect(fixture.selector.requestedIdentifiers.isEmpty)

    fixture.press(alphaServiceID)
    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("Another External Input Source Change during a hold does not restart it")
@MainActor
func anotherExternalChangeKeepsTheHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()
    fixture.press(betaServiceID)
    fixture.changeExternally(to: italian)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.betaID))

    fixture.changeExternally(to: us)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.betaID))
}

@Test("A change seen first by Activation Activity still starts the hold")
@MainActor
func changeSeenByActivationActivityStartsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.press(alphaServiceID)

    // The notification has not arrived yet when the next key press is handled.
    fixture.selector.current = italian
    fixture.press(alphaServiceID)

    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.alphaID))
    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("Hold Until Match continues until a keyboard assigned to the current Input Source is typed on")
@MainActor
func holdUntilMatchEndsOnMatchingKeyboard() throws {
    let fixture = try HoldFixture(response: .holdUntilMatch, betaAssignment: italian)
    fixture.holdItalianAfterTypingOnAlpha()
    #expect(fixture.switching.testingInputSourceHold == .untilMatch)
    #expect(fixture.switching.outcome.inputSourceHold == .holdUntilMatch)

    fixture.press(alphaServiceID)
    #expect(fixture.switching.testingInputSourceHold == .untilMatch)
    #expect(fixture.selector.current == italian)

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == nil)

    fixture.press(alphaServiceID)
    #expect(fixture.selector.current == us)
}

@Test("Hold Until Match is not ended by an unassigned keyboard")
@MainActor
func holdUntilMatchIgnoresUnassignedKeyboard() throws {
    let fixture = try HoldFixture(response: .holdUntilMatch, betaAssignment: nil)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == .untilMatch)
    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("No hold starts when the new Input Source equals the Active Physical Keyboard's Keyboard Assignment")
@MainActor
func noHoldWhenChangeMatchesActiveAssignment() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange, current: italian)
    fixture.switching.markActiveForTesting(fixture.alphaID)

    fixture.changeExternally(to: us)
    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("No hold starts while Paused or during Guided setup")
@MainActor
func noHoldWhenNotReady() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.press(alphaServiceID)

    fixture.switching.pause()
    fixture.changeExternally(to: italian)
    #expect(fixture.switching.testingInputSourceHold == nil)
    fixture.switching.resume()

    fixture.switching.appliesKeyboardAssignments = false
    fixture.changeExternally(to: other)
    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("The holding keyboard disconnecting ends the hold")
@MainActor
func holdingKeyboardDisconnectEndsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.discoverer.emit(.disconnected(serviceID: betaServiceID))
    #expect(fixture.switching.testingInputSourceHold != nil)

    fixture.discoverer.emit(.disconnected(serviceID: alphaServiceID))
    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("An excluded device produces no Activation Activity, so it never ends a hold")
@MainActor
func excludedDeviceNeverEndsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()
    fixture.model.excludePhysicalKeyboard(fixture.betaID)

    fixture.press(betaServiceID)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.alphaID))
    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("Pause then Resume ends the hold")
@MainActor
func pauseThenResumeEndsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.switching.pause()
    fixture.switching.resume()
    #expect(fixture.switching.testingInputSourceHold == nil)

    fixture.press(alphaServiceID)
    #expect(fixture.selector.requestedIdentifiers == [us, us])
}

@Test("Changing the External Change Response saves it and ends the hold")
@MainActor
func changingResponseEndsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    #expect(fixture.setupStore.externalChangeResponse == .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.switching.setExternalChangeResponse(.holdUntilMatch)
    #expect(fixture.setupStore.externalChangeResponse == .holdUntilMatch)
    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.switching.outcome.inputSourceHold == nil)
}

@Test("Editing or removing the holding keyboard's Keyboard Assignment ends the hold")
@MainActor
func editingHoldingKeyboardAssignmentEndsHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.model.setKeyboardAssignment(fixture.betaID, inputSourceIdentifier: us)
    #expect(fixture.switching.testingInputSourceHold != nil)

    fixture.model.setKeyboardAssignment(fixture.alphaID, inputSourceIdentifier: other)
    #expect(fixture.switching.testingInputSourceHold == nil)

    fixture.changeExternally(to: us)
    #expect(fixture.switching.testingInputSourceHold != nil)
    fixture.model.setKeyboardAssignment(fixture.alphaID, inputSourceIdentifier: nil)
    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("Switch Back Now ends the hold and applies the Active Physical Keyboard's Keyboard Assignment")
@MainActor
func switchBackNowEndsHoldAndApplies() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.switching.switchBackNow()
    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.selector.requestedIdentifiers == [us, us])
    #expect(fixture.selector.current == us)
    #expect(fixture.switching.outcome.mismatch == nil)
}

@Test("Sleep and wake keep the hold")
@MainActor
func sleepAndWakeKeepHold() throws {
    let fixture = try HoldFixture(response: .holdUntilKeyboardChange)
    fixture.holdItalianAfterTypingOnAlpha()

    fixture.switching.handleLifecycleEvent(.willSleep)
    fixture.switching.handleLifecycleEvent(.didWake)
    #expect(fixture.switching.testingInputSourceHold == .untilKeyboardChange(holdingPhysicalKeyboardID: fixture.alphaID))
}
