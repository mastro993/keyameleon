import Foundation
import AppKit
import Testing
@testable import Keyameleon

@Test("Permission revocation stops observation and later Input Source requests")
@MainActor
func permissionRevocationStopsObservationAndLaterInputSourceRequests() throws {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S.")
        ]),
        inputSourceSelector: selector,
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 954)))
    let keyboard = try #require(model.physicalKeyboards.first)
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.us")
    let lateEvent = try #require(eventObserver.onEvent)
    eventObserver.emit(PhysicalKeyboardEvent(serviceID: 954, kind: .press))
    try #require(selector.requestedIdentifiers == ["com.example.us"])
    selector.current = "com.example.other"

    permissionProvider.state = .denied
    startAndCheck(model)
    lateEvent(PhysicalKeyboardEvent(serviceID: 954, kind: .press))

    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
    #expect(eventObserver.stopCount == 1)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus.allowsActivityTriggeredSwitching == false)
    #expect(selector.requestedIdentifiers == ["com.example.us"])
    #expect(selector.current == "com.example.other")
}

@Test("Sleep and lock stop observation; wake and unlock resume automatically")
@MainActor
func sleepAndLockStopObservationWakeAndUnlockResumeAutomatically() {
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    #expect(eventObserver.startCount == 1)

    model.activityTriggeredSwitching.handleLifecycleEvent(.willSleep)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons.first == .sleeping)
    #expect(eventObserver.stopCount == 1)

    model.activityTriggeredSwitching.handleLifecycleEvent(.didWake)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(eventObserver.startCount == 2)

    model.activityTriggeredSwitching.handleLifecycleEvent(.sessionDidResignActive)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons.first == .inactiveSession)
    #expect(eventObserver.stopCount == 2)

    model.activityTriggeredSwitching.handleLifecycleEvent(.sessionDidBecomeActive)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(eventObserver.startCount == 3)
}

@Test("Wake restores saved Physical Keyboard records after lifecycle stop")
@MainActor
func wakeRestoresSavedPhysicalKeyboardRecordsAfterLifecycleStop() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore
    )

    startAndCheck(model)
    let facts = makeSetupModelHardwareFacts(serviceID: 901)
    discoverer.emit(.connected(facts))
    let keyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(keyboardID, customName: "Saved")
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    model.activityTriggeredSwitching.handleLifecycleEvent(.willSleep)

    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(model.physicalKeyboards[0].name == "Saved")
    #expect(
        recordStore.record(forIdentityKey: keyboardID.rawValue)?.keyboardAssignment
            == KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )

    model.activityTriggeredSwitching.handleLifecycleEvent(.didWake)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 902)))

    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].connectionState == .connected)
    #expect(model.physicalKeyboards[0].id == keyboardID)
    #expect(model.physicalKeyboards[0].name == "Saved")
    #expect(model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.us")
}

@Test("Positive Secure Input evidence sets Temporarily Unavailable and resumes without retry")
@MainActor
func positiveSecureInputEvidenceSetsTemporarilyUnavailableAndResumesWithoutRetry() {
    let protectedStateProvider = ProtectedStateTestProvider(state: .clear)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: protectedStateProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceSelector: selector,
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    protectedStateProvider.state = ProtectedStateSnapshot(
        isSecureInputEnabled: true,
        isProtectedDataAvailable: true
    )
    startAndCheck(model)

    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons.first == .secureInput)
    #expect(eventObserver.stopCount == 1)

    model.activityTriggeredSwitching.retryNow()
    #expect(selector.selectCount == 0)

    protectedStateProvider.state = .clear
    startAndCheck(model)

    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons.first == nil)
    #expect(eventObserver.startCount == 2)
}

@Test("Missing activity does not create Temporarily Unavailable")
@MainActor
func missingActivityDoesNotCreateTemporarilyUnavailable() {
    let protectedStateProvider = ProtectedStateTestProvider(state: .clear)
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: protectedStateProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )

    startAndCheck(model)

    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons.first == nil)
}

@Test("Protected lifecycle recovery keeps Paused status until user resumes")
@MainActor
func protectedLifecycleRecoveryKeepsPausedStatusUntilUserResumes() {
    let protectedStateProvider = ProtectedStateTestProvider(state: .clear)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: protectedStateProvider,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    model.activityTriggeredSwitching.start()
    model.activityTriggeredSwitching.pause()
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .paused)

    protectedStateProvider.state = ProtectedStateSnapshot(
        isSecureInputEnabled: true,
        isProtectedDataAvailable: true
    )
    startAndCheck(model)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(eventObserver.stopCount == 1)

    protectedStateProvider.state = .clear
    startAndCheck(model)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .paused)
    #expect(eventObserver.startCount == 1)
}

@Test("System lifecycle observer forwards public lifecycle notifications and stops cleanly")
@MainActor
func systemLifecycleObserverForwardsPublicLifecycleNotificationsAndStopsCleanly() {
    let workspaceCenter = NotificationCenter()
    let applicationCenter = NotificationCenter()
    let observer = SystemKeyameleonLifecycleObserver(
        workspaceNotificationCenter: workspaceCenter,
        applicationNotificationCenter: applicationCenter
    )
    var events: [KeyameleonLifecycleEvent] = []
    observer.start { event in
        events.append(event)
    }

    workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    applicationCenter.post(
        name: Notification.Name.NSApplicationProtectedDataWillBecomeUnavailable,
        object: nil
    )

    #expect(events == [.willSleep, .sessionDidBecomeActive, .protectedDataWillBecomeUnavailable])

    observer.stop()
    workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(events.count == 3)

    var restartedEvents: [KeyameleonLifecycleEvent] = []
    observer.start { event in
        restartedEvents.append(event)
    }
    defer { observer.stop() }
    workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(events == [.willSleep, .sessionDidBecomeActive, .protectedDataWillBecomeUnavailable])
    #expect(restartedEvents == [.didWake])
}

@MainActor
final class ProtectedStateTestProvider: ProtectedStateProviding {
    var state: ProtectedStateSnapshot

    init(state: ProtectedStateSnapshot) {
        self.state = state
    }

    func currentProtectedState() -> ProtectedStateSnapshot {
        state
    }
}

@Test(
    "Retry Now rechecks protected state before requesting a wanted Keyboard Assignment",
    arguments: [SwitchingUnavailableReason.secureInput, .protectedDataUnavailable]
)
@MainActor
func retryNowRechecksProtectedState(reason: SwitchingUnavailableReason) throws {
    let protectedStateProvider = ProtectedStateTestProvider(state: .clear)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other", verifySuccess: false)
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: protectedStateProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.other", name: "Other")
        ]),
        inputSourceSelector: selector
    )
    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 903)))
    let keyboard = try #require(model.physicalKeyboards.first)
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.us")
    model.activityTriggeredSwitching.handleActivationActivity(
        PhysicalKeyboardActivationActivity(physicalKeyboardID: keyboard.id)
    )
    try #require(model.activityTriggeredSwitching.outcome.hasAction(.retryNow))
    try #require(selector.requestedIdentifiers == ["com.example.us"])

    protectedStateProvider.state = ProtectedStateSnapshot(
        isSecureInputEnabled: reason == .secureInput,
        isProtectedDataAvailable: reason != .protectedDataUnavailable
    )
    model.activityTriggeredSwitching.retryNow()

    #expect(selector.requestedIdentifiers == ["com.example.us"])
    #expect(selector.current == "com.example.other")
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(model.activityTriggeredSwitching.outcome.temporarilyUnavailableReasons == [reason])
}
