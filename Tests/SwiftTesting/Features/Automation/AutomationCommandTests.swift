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
        ("keyameleon://set-external-change-response?value=switch-back", .setExternalChangeResponse(.switchBack)),
        ("keyameleon://set-external-change-response?value=hold-until-match", .setExternalChangeResponse(.holdUntilMatch)),
        (
            "keyameleon://set-external-change-response?value=hold-until-keyboard-change",
            .setExternalChangeResponse(.holdUntilKeyboardChange)
        ),
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
        "keyameleon://set-external-change-response",
        "keyameleon://set-external-change-response?value=holdUntilMatch",
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

@Test("Setting the External Change Response saves it")
@MainActor
func setExternalChangeResponseSavesIt() throws {
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = makeLifecycleModel(
        recordStore: InMemoryPhysicalKeyboardRecordStore(),
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        setupStore: setupStore
    )
    startAndCheck(model)

    try AutomationCommand.setExternalChangeResponse(.holdUntilKeyboardChange).perform(on: model.activityTriggeredSwitching)

    #expect(model.activityTriggeredSwitching.externalChangeResponse == .holdUntilKeyboardChange)
    #expect(setupStore.externalChangeResponse == .holdUntilKeyboardChange)
}

@Test("A short identifier, the last part of the identifier, selects in any language")
@MainActor
func selectFindsInputSourceByShortIdentifier() throws {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let switching = makeSwitching(selector: selector)

    try AutomationCommand.selectInputSource(.identifier("Italian")).perform(on: switching)
    #expect(selector.current == "com.example.italian")
}

@Test("A short identifier that fits two Input Sources selects neither")
@MainActor
func ambiguousShortIdentifierSelectsNothing() {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "org.other.us", name: "U.S. (Other)"),
            ]
        ),
        inputSourceSelector: selector
    )
    startAndCheck(model)

    #expect(throws: AutomationError.inputSourceUnavailable("us")) {
        try AutomationCommand.selectInputSource(.identifier("us")).perform(on: model.activityTriggeredSwitching)
    }
    #expect(selector.requestedIdentifiers.isEmpty)
}
