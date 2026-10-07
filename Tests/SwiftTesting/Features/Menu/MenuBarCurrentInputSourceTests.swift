import Observation
import Synchronization
import Testing
@testable import Keyameleon

@Test("Current Input Source matches exact saved assignments independently of keyboard activity")
@MainActor
func menuBarCurrentInputSourceMatchesExactSavedAssignments() {
    let source = EligibleInputSource(identifier: "us", name: "Same name", localeCode: "US")
    let other = EligibleInputSource(identifier: "other", name: source.name, localeCode: source.localeCode)
    let keyboards = [
        PreviewFixtures.physicalKeyboard(name: "Active", id: "active", assignment: "us", isActive: true),
        PreviewFixtures.physicalKeyboard(name: "Connected", id: "connected", assignment: "us"),
        PreviewFixtures.physicalKeyboard(name: "Disconnected", id: "disconnected", assignment: "us", connection: .disconnected),
        PreviewFixtures.physicalKeyboard(name: "Other", id: "other", assignment: "other")
    ]
    let sources = Dictionary(uniqueKeysWithValues: keyboards.map {
        ($0.id, $0.keyboardAssignment?.inputSourceIdentifier == "us" ? source : other)
    })
    let list = MenuBarAssignmentList(
        physicalKeyboards: keyboards,
        assignedInputSources: sources,
        currentInputSourceIdentifier: "us"
    )

    #expect(list.rows.filter(\.matchesCurrentInputSource).map(\.physicalKeyboardName).sorted()
        == ["Active", "Connected", "Disconnected"])
    #expect(list.rows.filter(\.isActive).map(\.physicalKeyboardName) == ["Active"])
    #expect(list.rows.first { $0.physicalKeyboardName == "Disconnected" }?.isDimmed == true)
    #expect(list.rows.first { $0.physicalKeyboardName == "Disconnected" }?.connectionMark == .disconnected)
    #expect(list.rows.first { $0.physicalKeyboardName == "Active" }?.accessibilityValue
        == "Same name, Active, Current Input Source")
    #expect(list.rows.first { $0.physicalKeyboardName == "Disconnected" }?.accessibilityValue
        == "Same name, Disconnected, Current Input Source")
    #expect(MenuBarAssignmentList(
        physicalKeyboards: keyboards,
        assignedInputSources: sources,
        currentInputSourceIdentifier: nil
    ).rows.allSatisfy { !$0.matchesCurrentInputSource })
}

@Test("Shared current assignment still moves Active Physical Keyboard without another selection")
@MainActor
func menuBarSharedCurrentSourceKeepsPhysicalActivityIndependent() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "us")
    let source = EligibleInputSource(identifier: "us", name: "U.S.", localeCode: "US")
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [source]),
        inputSourceSelector: selector
    )
    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 901)))
    let firstID = try #require(model.physicalKeyboards.first?.id)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(
        serviceID: 902, identity: "macos.keyboard.second", serialNumber: "keyboard-b"
    )))
    let secondID = try #require(model.physicalKeyboards.first { $0.id != firstID }?.id)
    for keyboard in model.physicalKeyboards {
        model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: source.identifier)
    }
    let sources = [firstID: source, secondID: source]
    let beforeActivity = MenuBarAssignmentList(
        physicalKeyboards: model.physicalKeyboards,
        assignedInputSources: sources,
        currentInputSourceIdentifier: model.currentInputSourceIdentifier
    )
    #expect(beforeActivity.rows.allSatisfy { $0.matchesCurrentInputSource })
    #expect(beforeActivity.rows.allSatisfy { !$0.isActive })

    let discovery = model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery
    discovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 901, kind: .press))
    #expect(model.activePhysicalKeyboardID == firstID)
    let selectionsAfterFirstActivity = selector.selectCount
    discovery.handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 902, kind: .press))
    let content = MenuBarPanelContent(
        outcome: model.activityTriggeredSwitching.outcome,
        physicalKeyboards: model.physicalKeyboards,
        assignedInputSources: sources,
        currentInputSourceIdentifier: model.currentInputSourceIdentifier,
        marketingVersion: nil,
        canCheckForUpdates: false
    )
    #expect(content.assignmentList.rows.allSatisfy { $0.matchesCurrentInputSource })
    #expect(content.assignmentList.rows.filter(\.isActive).map(\.id) == [secondID.rawValue])
    #expect(selector.selectCount == selectionsAfterFirstActivity)
}

@Test("Exact current identifier is observable immediately after selection despite equal source names")
@MainActor
func menuBarCurrentSourceObservesImmediateSelectionReadback() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let changeObserver = SetupModelTestInputSourceChangeObserver()
    let selector = SetupModelTestInputSourceSelector(current: "other")
    let sources = [
        EligibleInputSource(identifier: "us", name: "Same name", localeCode: "US"),
        EligibleInputSource(identifier: "other", name: "Same name", localeCode: "US")
    ]
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: sources),
        inputSourceSelector: selector,
        inputSourceChangeObserver: changeObserver
    )
    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 903)))
    let keyboardID = try #require(model.physicalKeyboards.first?.id)
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "us")
    let changed = Mutex(false)
    withObservationTracking {
        #expect(model.currentInputSourceIdentifier == "other")
    } onChange: {
        changed.withLock { $0 = true }
    }

    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 903, kind: .press)
    )
    #expect(model.currentInputSourceIdentifier == "us")
    #expect(changed.withLock { $0 })
    #expect(selector.selectCount == 1)
    let selectedSourceName = model.activityTriggeredSwitching.outcome.currentInputSourceName
    changed.withLock { $0 = false }
    withObservationTracking {
        _ = model.currentInputSourceIdentifier
    } onChange: {
        changed.withLock { $0 = true }
    }
    selector.current = "other"
    changeObserver.emit()
    #expect(model.currentInputSourceIdentifier == "other")
    #expect(model.activityTriggeredSwitching.outcome.currentInputSourceName == selectedSourceName)
    #expect(changed.withLock { $0 })
    #expect(model.activePhysicalKeyboardID == keyboardID)
    #expect(selector.selectCount == 1)
}

@Test("Opening paused menu refreshes current source without selecting or observing physical input")
@MainActor
func menuBarPausedOpeningRefreshesCurrentSource() {
    let selector = SetupModelTestInputSourceSelector(current: "us")
    let events = SetupModelTestPhysicalKeyboardEventObserver()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceSelector: selector,
        physicalKeyboardEventObserver: events
    )
    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    model.activityTriggeredSwitching.pause()
    let controller = MenuBarPanelController(
        setupModel: model,
        switching: model.activityTriggeredSwitching,
        generalSettingsModel: GeneralSettingsModel(
            launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
            updateChecker: FakeUpdateChecker(canCheck: false)
        ),
        actions: MenuBarPanelActions(continueSetup: {}, openSettings: {}, checkForUpdates: {}, quit: {})
    )
    let observationStarts = events.startCount
    selector.current = "other"
    controller.menuNeedsUpdate(controller.menu)

    #expect(model.currentInputSourceIdentifier == "other")
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .paused)
    #expect(selector.selectCount == 0)
    #expect(events.startCount == observationStarts)
}
