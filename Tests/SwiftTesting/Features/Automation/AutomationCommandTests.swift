import Foundation
import Testing
@testable import Keyameleon

@Test(
    "The URL scheme names one command per action",
    arguments: [
        ("keyameleon://pause", AutomationCommand.pause),
        ("keyameleon://resume", .resume),
        ("keyameleon://toggle-pause", .togglePause),
        ("keyameleon-dev://Pause", .pause),
        ("keyameleon://select-input-source?id=com.apple.keylayout.US", .selectInputSource(.identifier("com.apple.keylayout.US"))),
        ("keyameleon://select-input-source?name=U.S.", .selectInputSource(.name("U.S."))),
    ]
)
func urlNamesCommand(url: String, command: AutomationCommand) throws {
    #expect(AutomationCommand(url: try #require(URL(string: url))) == command)
}

@Test(
    "A URL without a known action or Input Source is rejected",
    arguments: [
        "keyameleon://quit",
        "keyameleon://",
        "keyameleon://select-input-source",
        "keyameleon://select-input-source?id=",
    ]
)
func urlWithoutCommandIsRejected(url: String) throws {
    #expect(AutomationCommand(url: try #require(URL(string: url))) == nil)
}

@MainActor
private func makeSwitching(selector: SetupModelTestInputSourceSelector) -> ActivityTriggeredSwitching {
    let model = makeLifecycleModel(
        recordStore: InMemoryPhysicalKeyboardRecordStore(),
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        selector: selector
    )
    startAndCheck(model)
    return model.activityTriggeredSwitching
}

@Test("Toggle Pause pauses Ready switching and resumes paused switching")
@MainActor
func togglePausePausesAndResumes() throws {
    let switching = makeSwitching(selector: SetupModelTestInputSourceSelector())

    try AutomationCommand.togglePause.perform(on: switching)
    #expect(switching.outcome.switchingStatus == .paused)

    try AutomationCommand.togglePause.perform(on: switching)
    #expect(switching.outcome.switchingStatus == .ready)
}

@Test("Pause and Resume leave switching as they find it when already there")
@MainActor
func pauseAndResumeAreIdempotent() throws {
    let switching = makeSwitching(selector: SetupModelTestInputSourceSelector())

    try AutomationCommand.resume.perform(on: switching)
    #expect(switching.outcome.switchingStatus == .ready)
    try AutomationCommand.pause.perform(on: switching)
    try AutomationCommand.pause.perform(on: switching)
    #expect(switching.outcome.switchingStatus == .paused)
}

@Test("An Input Source is found by its exact name or identifier")
@MainActor
func selectFindsInputSourceByNameOrIdentifier() throws {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let switching = makeSwitching(selector: selector)

    try AutomationCommand.selectInputSource(.name("Italian")).perform(on: switching)
    #expect(selector.current == "com.example.italian")

    try AutomationCommand.selectInputSource(.identifier("com.example.us")).perform(on: switching)
    #expect(selector.current == "com.example.us")
}

@Test("An Input Source that is not available selects nothing")
@MainActor
func selectUnknownInputSourceThrows() {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let switching = makeSwitching(selector: selector)

    #expect(throws: AutomationError.inputSourceUnavailable("Greek")) {
        try AutomationCommand.selectInputSource(.name("Greek")).perform(on: switching)
    }
    #expect(selector.requestedIdentifiers.isEmpty)
}

@Test("A selection whose readback does not match reports the failure")
@MainActor
func selectReportsFailedReadback() {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us", verifySuccess: false)
    let switching = makeSwitching(selector: selector)

    #expect(throws: AutomationError.selectionFailed("Italian")) {
        try AutomationCommand.selectInputSource(.name("Italian")).perform(on: switching)
    }
}
