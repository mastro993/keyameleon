import Foundation
import Testing
@testable import Keyameleon

@Test("Switching Status priority is Permission, Temporarily Unavailable, Paused, Ready")
func switchingStatusPriorityIsPermissionTemporarilyUnavailablePausedReady() {
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .denied,
            isTemporarilyUnavailable: true,
            isPaused: true
        ) == .permissionRequired
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .unknown,
            isTemporarilyUnavailable: false,
            isPaused: true
        ) == .permissionRequired
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: true,
            isPaused: true
        ) == .temporarilyUnavailable
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: false,
            isPaused: true
        ) == .paused
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: false,
            isPaused: false
        ) == .ready
    )
}

@Test("Paused and Ready allow discovery; only Ready allows Activity-Triggered Switching")
func pausedAndReadyAllowDiscoveryOnlyReadyAllowsSwitching() {
    #expect(SwitchingStatus.ready.allowsActivityTriggeredSwitching)
    #expect(SwitchingStatus.ready.allowsPhysicalKeyboardDiscovery)
    #expect(!SwitchingStatus.paused.allowsActivityTriggeredSwitching)
    #expect(SwitchingStatus.paused.allowsPhysicalKeyboardDiscovery)
    #expect(!SwitchingStatus.permissionRequired.allowsActivityTriggeredSwitching)
    #expect(!SwitchingStatus.permissionRequired.allowsPhysicalKeyboardDiscovery)
    #expect(!SwitchingStatus.temporarilyUnavailable.allowsActivityTriggeredSwitching)
    #expect(!SwitchingStatus.temporarilyUnavailable.allowsPhysicalKeyboardDiscovery)
}

@Test("Menu bar icon mark prefers global status over item warnings")
func menuBarIconMarkPrefersGlobalStatusOverItemWarnings() {
    #expect(
        MenuBarIconMark.resolve(
            switchingStatus: .permissionRequired,
            hasItemConditionsNeedingAction: true
        ) == .permissionRequired
    )
    #expect(
        MenuBarIconMark.resolve(
            switchingStatus: .temporarilyUnavailable,
            hasItemConditionsNeedingAction: true
        ) == .temporarilyUnavailable
    )
    #expect(
        MenuBarIconMark.resolve(
            switchingStatus: .paused,
            hasItemConditionsNeedingAction: true
        ) == .paused
    )
    #expect(
        MenuBarIconMark.resolve(
            switchingStatus: .ready,
            hasItemConditionsNeedingAction: true
        ) == .warning
    )
    #expect(
        MenuBarIconMark.resolve(
            switchingStatus: .ready,
            hasItemConditionsNeedingAction: false
        ) == .ready
    )
}

@Test("Menu bar icon marks use distinct SF Symbol names")
func menuBarIconMarksUseDistinctSFSymbolNames() {
    let names = [
        MenuBarIconMark.ready.systemSymbolName,
        MenuBarIconMark.permissionRequired.systemSymbolName,
        MenuBarIconMark.temporarilyUnavailable.systemSymbolName,
        MenuBarIconMark.paused.systemSymbolName,
        MenuBarIconMark.warning.systemSymbolName,
    ]
    #expect(Set(names).count == names.count)
}

@Test("Pause Activity-Triggered Switching stops Key Content observation and Input Source requests")
@MainActor
func pauseStopsKeyContentObservationAndInputSourceRequests() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceSelector: selector,
        physicalKeyboardEventObserver: eventObserver
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 701)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    #expect(eventObserver.startCount == 1)
    #expect(model.switchingStatus == .ready)

    model.pauseActivityTriggeredSwitching()

    #expect(model.switchingStatus == .paused)
    #expect(model.isActivityTriggeredSwitchingPaused)
    #expect(setupStore.isActivityTriggeredSwitchingPaused)
    #expect(eventObserver.stopCount == 1)
    #expect(!model.canObservePhysicalKeyboards)
    #expect(!model.canRequestInputSources)
    #expect(model.canDiscoverPhysicalKeyboards)

    model.handlePhysicalKeyboardEvent(
        PhysicalKeyboardEvent(serviceID: 701, kind: .press)
    )
    #expect(selector.selectCount == 0)
    #expect(model.activePhysicalKeyboardID == nil)

    // Discovery still works for management while Paused.
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 702,
                identity: "macos.keyboard.other",
                serialNumber: "keyboard-b"
            )
        )
    )
    #expect(model.physicalKeyboards.count == 2)
}

@Test("Pause persists across restart; Active Physical Keyboard does not")
@MainActor
func pausePersistsAcrossRestartActivePhysicalKeyboardDoesNot() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 711)))
    model.handlePhysicalKeyboardEvent(
        PhysicalKeyboardEvent(serviceID: 711, kind: .press)
    )
    #expect(model.activePhysicalKeyboardID != nil)
    model.pauseActivityTriggeredSwitching()
    #expect(setupStore.isActivityTriggeredSwitchingPaused)

    let restarted = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        physicalKeyboardRecordStore: recordStore
    )

    #expect(restarted.isActivityTriggeredSwitchingPaused)
    #expect(restarted.switchingStatus == .paused)
    #expect(restarted.activePhysicalKeyboardID == nil)
    #expect(restarted.activePhysicalKeyboardMenuValue == KeyameleonAppMetadata.noActivityObservedYet)
}

@Test("Resume rechecks listen permission before observation starts")
@MainActor
func resumeRechecksListenPermissionBeforeObservationStarts() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.setActivityTriggeredSwitchingPaused(true)
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardEventObserver: eventObserver
    )

    #expect(model.switchingStatus == .paused)
    #expect(eventObserver.startCount == 0)

    permissionProvider.state = .denied
    let checksBeforeResume = permissionProvider.checkCount
    model.resumeActivityTriggeredSwitching()

    #expect(permissionProvider.checkCount > checksBeforeResume)
    #expect(!model.isActivityTriggeredSwitchingPaused)
    #expect(model.switchingStatus == .permissionRequired)
    #expect(eventObserver.startCount == 0)
    #expect(eventObserver.stopCount == 0)

    permissionProvider.state = .granted
    model.resumeActivityTriggeredSwitching()
    // Already resumed; refresh path via resume no-ops when not paused.
    model.refreshPermission()
    #expect(model.switchingStatus == .ready)
    #expect(eventObserver.startCount == 1)
}

@Test("Resume from paused with permission starts observation")
@MainActor
func resumeFromPausedWithPermissionStartsObservation() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardEventObserver: eventObserver
    )

    model.refreshPermission()
    #expect(eventObserver.startCount == 1)
    model.pauseActivityTriggeredSwitching()
    #expect(eventObserver.stopCount == 1)

    let checksBefore = permissionProvider.checkCount
    model.resumeActivityTriggeredSwitching()
    #expect(permissionProvider.checkCount > checksBefore)
    #expect(model.switchingStatus == .ready)
    #expect(eventObserver.startCount == 2)
}

@Test("Permission Required still beats pause after resume denial")
@MainActor
func permissionRequiredBeatsPauseAfterResumeDenial() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    model.refreshPermission()
    model.pauseActivityTriggeredSwitching()
    permissionProvider.state = .denied
    model.refreshPermission()

    #expect(model.isActivityTriggeredSwitchingPaused)
    #expect(model.switchingStatus == .permissionRequired)
}

@Test("Menu first action items list unassigned and unavailable assignments")
@MainActor
func menuFirstActionItemsListUnassignedAndUnavailableAssignments() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [EligibleInputSource(identifier: "com.example.us", name: "U.S.")]
        )
    )

    model.refreshPermission()
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 721,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-a"
            )
        )
    )
    model.setPhysicalKeyboardName(model.physicalKeyboards[0].id, customName: "Alpha")

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 722,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-b"
            )
        )
    )
    let betaID = model.physicalKeyboards.first { $0.name != "Alpha" }!.id
    model.setPhysicalKeyboardName(betaID, customName: "Beta")
    model.setKeyboardAssignment(betaID, inputSourceIdentifier: "com.example.missing")

    let items = model.menuFirstActionItems
    #expect(
        items.contains(.unassigned(physicalKeyboardName: "Alpha"))
    )
    #expect(
        items.contains(.unavailableKeyboardAssignment(physicalKeyboardName: "Beta"))
    )
}

@Test("Active Keyboard Assignment and Current Input Source menu values")
@MainActor
func activeKeyboardAssignmentAndCurrentInputSourceMenuValues() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.it", name: "Italian"),
            ]
        ),
        inputSourceSelector: selector
    )

    model.refreshPermission()
    #expect(model.activePhysicalKeyboardMenuValue == KeyameleonAppMetadata.noActivityObservedYet)
    #expect(model.activeKeyboardAssignmentMenuValue == "—")
    #expect(model.currentInputSourceMenuValue == "U.S.")

    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 731)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.it")
    model.handlePhysicalKeyboardEvent(
        PhysicalKeyboardEvent(serviceID: 731, kind: .press)
    )

    #expect(model.activePhysicalKeyboardMenuValue == "Test Keyboard")
    #expect(model.activeKeyboardAssignmentMenuValue == "Italian")
    #expect(model.currentInputSourceMenuValue == "Italian")
}

@Test("UserDefaults pause flag survives store re-read")
@MainActor
func userDefaultsPauseFlagSurvivesStoreReread() {
    let suiteName = "dev.fedemas.keyameleon.tests.pause.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsSetupDecisionStore(defaults: defaults)
    #expect(!store.isActivityTriggeredSwitchingPaused)
    store.setActivityTriggeredSwitchingPaused(true)

    let reloaded = UserDefaultsSetupDecisionStore(defaults: defaults)
    #expect(reloaded.isActivityTriggeredSwitchingPaused)
}
