import Testing
@testable import Keyameleon

private let us = "com.example.us"
private let italian = "com.example.italian"
private let alphaServiceID: UInt64 = 911

/// One connected Physical Keyboard assigned to U.S., typed on once. The module
/// is Ready and Guided setup is complete.
@MainActor
private struct AutomationFixture {
    let model: SetupModel
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: us)

    var switching: ActivityTriggeredSwitching {
        model.activityTriggeredSwitching
    }

    init(response: ExternalChangeResponse) throws {
        model = makeLifecycleModel(
            recordStore: InMemoryPhysicalKeyboardRecordStore(),
            discoverer: discoverer,
            selector: selector
        )
        startAndCheck(model)
        discoverer.emit(.connected(makeSetupModelHardwareFacts(
            serviceID: alphaServiceID,
            identity: "macos.keyboard.alpha",
            serialNumber: "serial-alpha"
        )))
        let alphaID = try #require(model.physicalKeyboards.first?.id)
        model.setKeyboardAssignment(alphaID, inputSourceIdentifier: us)
        switching.setExternalChangeResponse(response)
        press()
    }

    func press() {
        switching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(serviceID: alphaServiceID, kind: .press)
        )
    }
}

@Test("Selecting an Input Source from automation is an External Input Source Change")
@MainActor
func automationSelectionStartsHold() throws {
    let fixture = try AutomationFixture(response: .holdUntilMatch)

    try fixture.switching.selectInputSource(.identifier(italian))

    #expect(fixture.selector.current == italian)
    #expect(fixture.switching.outcome.inputSourceHold == .holdUntilMatch)
    fixture.press()
    #expect(fixture.selector.current == italian)
}

@Test("With Switch Back, the next Activation Activity undoes a selection from automation")
@MainActor
func automationSelectionSwitchesBackOnNextActivity() throws {
    let fixture = try AutomationFixture(response: .switchBack)

    try fixture.switching.selectInputSource(.identifier(italian))
    #expect(fixture.switching.outcome.inputSourceHold == nil)

    fixture.press()
    #expect(fixture.selector.current == us)
}

@Test("While paused, a selection from automation shows as the current Input Source and starts no hold")
@MainActor
func automationSelectionWhilePausedUpdatesCurrentInputSource() throws {
    let fixture = try AutomationFixture(response: .holdUntilMatch)
    fixture.switching.pause()

    try fixture.switching.selectInputSource(.identifier(italian))

    #expect(fixture.switching.outcome.currentInputSourceName == "Italian")
    #expect(fixture.switching.outcome.inputSourceHold == nil)
}
