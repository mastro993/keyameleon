import Foundation
import Testing
@testable import Keyameleon

private let us = "com.example.us"
private let italian = "com.example.italian"
private let other = "com.example.other"
private let alphaServiceID: UInt64 = 911
private let terminal = FrontmostApp(bundleIdentifier: "com.apple.Terminal", name: "Terminal")
private let notes = FrontmostApp(bundleIdentifier: "com.apple.Notes", name: "Notes")

/// One connected Physical Keyboard, alpha, assigned to Italian, and Terminal
/// assigned to U.S. The module is Ready and Guided setup is complete.
@MainActor
private struct AppFixture {
    let model: SetupModel
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector: SetupModelTestInputSourceSelector
    let changeObserver = SetupModelTestInputSourceChangeObserver()
    let appAssignmentStore: InMemoryAppAssignmentStore
    let alphaID: PhysicalKeyboardRecordID

    var switching: ActivityTriggeredSwitching {
        model.activityTriggeredSwitching
    }

    init(
        response: ExternalChangeResponse = .switchBack,
        terminalAssignment: String = us,
        current: String = other
    ) throws {
        selector = SetupModelTestInputSourceSelector(current: current)
        appAssignmentStore = InMemoryAppAssignmentStore([
            AppAssignment(
                bundleIdentifier: terminal.bundleIdentifier,
                appName: terminal.name,
                inputSourceIdentifier: terminalAssignment
            )
        ])
        model = SetupModel(
            permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
            setupStore: SetupModelTestSetupDecisionStore(),
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
            inputSourceChangeObserver: changeObserver,
            appAssignmentStore: appAssignmentStore
        )
        startAndCheck(model)
        discoverer.emit(.connected(makeSetupModelHardwareFacts(
            serviceID: alphaServiceID,
            identity: "macos.keyboard.alpha",
            serialNumber: "serial-alpha"
        )))
        alphaID = try #require(model.physicalKeyboards.first?.id)
        model.setKeyboardAssignment(alphaID, inputSourceIdentifier: italian)
        switching.setExternalChangeResponse(response)
    }

    func press() {
        switching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(serviceID: alphaServiceID, kind: .press)
        )
    }

    func changeExternally(to identifier: String) {
        selector.current = identifier
        changeObserver.emit()
    }
}

@Test("An App Assignment overrides the Keyboard Assignment while its app is frontmost")
@MainActor
func appAssignmentOverridesKeyboardAssignment() throws {
    let fixture = try AppFixture()
    fixture.press()
    fixture.switching.handleAppActivation(terminal)
    fixture.press()

    #expect(fixture.selector.requestedIdentifiers == [italian, us])
}

@Test("Leaving an assigned app switches straight back to the Keyboard Assignment")
@MainActor
func leavingAssignedAppAppliesKeyboardAssignment() throws {
    let fixture = try AppFixture()
    fixture.press()
    fixture.switching.handleAppActivation(terminal)
    fixture.switching.handleAppActivation(notes)

    #expect(fixture.selector.requestedIdentifiers == [italian, us, italian])
}

@Test("An App Assignment applies before any Activation Activity")
@MainActor
func appAssignmentAppliesWithoutActivePhysicalKeyboard() throws {
    let fixture = try AppFixture()
    fixture.switching.handleAppActivation(terminal)

    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("Keyameleon becoming active is not an App Activation")
@MainActor
func ownActivationKeepsFrontmostApp() throws {
    let fixture = try AppFixture()
    let ownBundleIdentifier = try #require(Bundle.main.bundleIdentifier)
    fixture.switching.handleAppActivation(terminal)
    fixture.switching.handleAppActivation(FrontmostApp(bundleIdentifier: ownBundleIdentifier, name: "Keyameleon"))
    fixture.press()

    #expect(fixture.selector.requestedIdentifiers == [us])
    #expect(fixture.switching.outcome.frontmostAppAssignment?.appName == "Terminal")
}

@Test("No App Activation selects anything during Guided setup")
@MainActor
func appActivationSelectsNothingDuringSetup() throws {
    let fixture = try AppFixture()
    fixture.switching.appliesKeyboardAssignments = false
    fixture.switching.handleAppActivation(terminal)

    #expect(fixture.selector.requestedIdentifiers.isEmpty)
}

@Test("An Unavailable App Assignment selects nothing and does not fall back to the Keyboard Assignment")
@MainActor
func unavailableAppAssignmentSelectsNothing() throws {
    let fixture = try AppFixture(terminalAssignment: "com.example.missing")
    fixture.press()
    fixture.switching.handleAppActivation(terminal)
    fixture.press()

    #expect(fixture.selector.requestedIdentifiers == [italian])
    #expect(fixture.switching.outcome.warnings.contains { $0.category == .unavailableAppAssignment })
    #expect(fixture.switching.outcome.frontmostAppAssignment?.inputSource == nil)
}

@Test("An App Activation ends an Input Source Hold and applies the Wanted Input Source")
@MainActor
func appActivationEndsHold() throws {
    let fixture = try AppFixture(response: .holdUntilKeyboardChange)
    fixture.press()
    fixture.changeExternally(to: other)
    #expect(fixture.switching.testingInputSourceHold != nil)

    fixture.switching.handleAppActivation(terminal)

    #expect(fixture.switching.testingInputSourceHold == nil)
    #expect(fixture.selector.requestedIdentifiers == [italian, us])
}

@Test("Hold Until Match ends only when the Wanted Input Source matches, not the Keyboard Assignment")
@MainActor
func holdUntilMatchComparesWantedInputSource() throws {
    let fixture = try AppFixture(response: .holdUntilMatch)
    fixture.switching.handleAppActivation(terminal)
    fixture.changeExternally(to: italian)
    // Alpha's Keyboard Assignment is Italian, but Terminal wants U.S.
    fixture.press()

    #expect(fixture.switching.testingInputSourceHold == .untilMatch)
    #expect(fixture.selector.requestedIdentifiers == [us])
}

@Test("No hold starts when an external change reaches the Wanted Input Source")
@MainActor
func noHoldWhenChangeReachesWantedInputSource() throws {
    let fixture = try AppFixture()
    fixture.switching.handleAppActivation(terminal)
    fixture.changeExternally(to: italian)
    fixture.switching.setExternalChangeResponse(.holdUntilMatch)
    // Terminal wants U.S.; there is no Active Physical Keyboard yet.
    fixture.changeExternally(to: us)

    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("Editing the Frontmost App's App Assignment ends an Input Source Hold")
@MainActor
func editingFrontmostAppAssignmentEndsHold() throws {
    let fixture = try AppFixture(response: .holdUntilMatch)
    fixture.switching.handleAppActivation(terminal)
    fixture.changeExternally(to: italian)
    #expect(fixture.switching.testingInputSourceHold != nil)

    fixture.appAssignmentStore.saveAppAssignment(AppAssignment(
        bundleIdentifier: terminal.bundleIdentifier,
        appName: terminal.name,
        inputSourceIdentifier: other
    ))

    #expect(fixture.switching.testingInputSourceHold == nil)
}

@Test("The mismatch notice names the app whose App Assignment is wanted")
@MainActor
func mismatchNamesFrontmostApp() throws {
    let fixture = try AppFixture()
    fixture.switching.handleAppActivation(terminal)
    fixture.changeExternally(to: italian)

    #expect(fixture.switching.outcome.mismatch?.appName == "Terminal")
    #expect(fixture.switching.outcome.mismatch?.assignedName == "U.S.")
}
