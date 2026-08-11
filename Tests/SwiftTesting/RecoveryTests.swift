import Testing
@testable import Keyameleon

@Test("Selection failure leaves normal input unchanged and opens one warning episode")
@MainActor
func selectionFailureLeavesNormalInputUnchangedAndOpensOneWarningEpisode() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 301)))
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 301, kind: .press))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 301, kind: .repeat))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 301, kind: .press))

    #expect(selector.selectCount == 3)
    #expect(selector.currentInputSourceIdentifier() == "com.example.other")
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == nil)
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.count == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].category == .selectionFailed)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].recoveryAction == .retryNow)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].supportsRetryNow)
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment?.inputSourceIdentifier == "com.example.us")
}

@Test("Retry Now retries current wanted Keyboard Assignment")
@MainActor
func retryNowRetriesCurrentWantedKeyboardAssignment() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 302)))
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 302, kind: .press))
    #expect(selector.selectCount == 1)
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)

    model.activityTriggeredSwitching.retryNow()
    #expect(selector.selectCount == 2)
    #expect(selector.lastRequestedIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.count == 1)

    selector.verifySuccess = true
    model.activityTriggeredSwitching.retryNow()
    #expect(selector.selectCount == 3)
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.isEmpty)
    #expect(selector.currentInputSourceIdentifier() == "com.example.us")
}

@Test("Later assigned Activation Activity replaces wanted state and can start new request")
@MainActor
func laterAssignedActivationActivityReplacesWantedStateAndCanStartNewRequest() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.it", name: "Italian"),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 303,
                identity: "macos.keyboard.a",
                serialNumber: "serial-a"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 304,
                identity: "macos.keyboard.b",
                serialNumber: "serial-b"
            )
        )
    )

    let keyboardA = model.physicalKeyboards.first {
        $0.id.rawValue.contains("macos.keyboard.a")
    }!
    let keyboardB = model.physicalKeyboards.first {
        $0.id.rawValue.contains("macos.keyboard.b")
    }!
    model.setKeyboardAssignment(keyboardA.id, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(keyboardB.id, inputSourceIdentifier: "com.example.it")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 303, kind: .press))
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment?.inputSourceIdentifier == "com.example.us")
    #expect(selector.lastRequestedIdentifier == "com.example.us")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 304, kind: .press))
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment?.inputSourceIdentifier == "com.example.it")
    #expect(selector.lastRequestedIdentifier == "com.example.it")
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment?.physicalKeyboardID == keyboardB.id)
    // Still one selection-failure warning cause, not one per event.
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.count == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].cause == .selectionFailure)
}

@Test("Missing assigned Input Source becomes Unavailable Keyboard Assignment without selection")
@MainActor
func missingAssignedInputSourceBecomesUnavailableKeyboardAssignmentWithoutSelection() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.other", name: "Other")
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 305)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.missing")

    #expect(isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.missing")
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.count == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].category == .unavailableKeyboardAssignment)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings[0].recoveryAction == .changeOrRemoveAssignment)

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 305, kind: .press))
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 305, kind: .repeat))

    #expect(selector.selectCount == 0)
    #expect(selector.currentInputSourceIdentifier() == "com.example.other")
    #expect(model.activePhysicalKeyboardID == keyboardID)
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.count == 1)
}

@Test("Exact Input Source return ends unavailable condition and restores switching")
@MainActor
func exactInputSourceReturnEndsUnavailableConditionAndRestoresSwitching() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.other", name: "Other")
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 306)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    #expect(isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)

    inputSources.inputSources = [
        EligibleInputSource(identifier: "com.example.other", name: "Other"),
        EligibleInputSource(identifier: "com.example.us", name: "U.S."),
    ]
    startAndCheck(model)

    #expect(!isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.isEmpty)
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.us"
    )

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 306, kind: .press))
    #expect(selector.selectCount == 1)
    #expect(selector.lastRequestedIdentifier == "com.example.us")
    #expect(model.activityTriggeredSwitching.testingVerifiedKeyboardAssignmentIdentifier == "com.example.us")
}

@Test("Change Assignment and Remove Assignment clear Unavailable Keyboard Assignment")
@MainActor
func changeAssignmentAndRemoveAssignmentClearUnavailableKeyboardAssignment() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.it", name: "Italian")
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 307)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.missing")
    #expect(isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 1)

    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.it")
    #expect(!isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.isEmpty)
    #expect(model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.it")

    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.gone")
    #expect(isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.activityTriggeredSwitching.testingWarningEpisodeCount == 2)

    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: nil)
    #expect(!isUnavailableKeyboardAssignment(model, for: keyboardID))
    #expect(model.physicalKeyboards[0].keyboardAssignment == nil)
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.isEmpty)
}

@Test("Keyboard Assignment availability uses exact identifier only")
func keyboardAssignmentAvailabilityUsesExactIdentifierOnly() {
    let assignment = KeyboardAssignment(inputSourceIdentifier: "com.example.us")!
    #expect(
        KeyboardAssignmentAvailability.isAvailable(
            assignment,
            eligibleIdentifiers: ["com.example.us"]
        )
    )
    #expect(
        !KeyboardAssignmentAvailability.isAvailable(
            assignment,
            eligibleIdentifiers: ["com.example.US"]
        )
    )
    #expect(
        !KeyboardAssignmentAvailability.isAvailable(
            assignment,
            eligibleIdentifiers: ["com.apple.keylayout.US"]
        )
    )
}

@Test("Unavailable Activation Activity clears prior selection-failure warning")
@MainActor
func unavailableActivationActivityClearsPriorSelectionFailureWarning() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 308,
                identity: "macos.keyboard.ok",
                serialNumber: "serial-ok"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 309,
                identity: "macos.keyboard.missing",
                serialNumber: "serial-missing"
            )
        )
    )

    let okID = model.physicalKeyboards.first { $0.id.rawValue.contains("macos.keyboard.ok") }!.id
    let missingID = model.physicalKeyboards.first {
        $0.id.rawValue.contains("macos.keyboard.missing")
    }!.id
    model.setKeyboardAssignment(okID, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(missingID, inputSourceIdentifier: "com.example.gone")

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 308, kind: .press))
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.contains { $0.cause == .selectionFailure })

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 309, kind: .press))
    #expect(!model.activityTriggeredSwitching.testingActiveWarnings.contains { $0.cause == .selectionFailure })
    #expect(
        model.activityTriggeredSwitching.testingActiveWarnings.contains {
            $0.cause == .unavailableKeyboardAssignment(missingID)
        }
    )
    #expect(selector.selectCount == 1)
}

@Test("Change Assignment clears selection-failure warning for that wanted keyboard")
@MainActor
func changeAssignmentClearsSelectionFailureWarningForThatWantedKeyboard() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let inputSources = SetupModelTestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.it", name: "Italian"),
            EligibleInputSource(identifier: "com.example.other", name: "Other"),
        ]
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 310)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 310, kind: .press))
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.contains { $0.cause == .selectionFailure })

    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.it")
    #expect(!model.activityTriggeredSwitching.testingActiveWarnings.contains { $0.cause == .selectionFailure })
    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment?.inputSourceIdentifier == "com.example.it")
}
