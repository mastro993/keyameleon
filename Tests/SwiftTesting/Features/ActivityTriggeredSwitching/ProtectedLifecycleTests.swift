import Foundation
import AppKit
import Testing
@testable import Keyameleon

@Test("Permission revocation stops observation and later Input Source requests")
@MainActor
func permissionRevocationStopsObservationAndLaterInputSourceRequests() {
    let permissionProvider = SetupModelTestListenPermissionProvider(state: .granted)
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        inputSourceSelector: selector,
        physicalKeyboardEventObserver: eventObserver
    )

    startAndCheck(model)
    #expect(eventObserver.startCount == 1)

    permissionProvider.state = .denied
    startAndCheck(model)

    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .permissionRequired)
    #expect(eventObserver.stopCount == 1)
    #expect(!model.activityTriggeredSwitching.outcome.switchingStatus.allowsActivityTriggeredSwitching)
    #expect(!model.activityTriggeredSwitching.outcome.switchingStatus.allowsActivityTriggeredSwitching)
    #expect(selector.selectCount == 0)
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
func systemLifecycleObserverForwardsPublicLifecycleNotificationsAndStopsCleanly() async {
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
    await Task.yield()

    #expect(events == [.willSleep, .sessionDidBecomeActive, .protectedDataWillBecomeUnavailable])

    observer.stop()
    workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    await Task.yield()
    #expect(events.count == 3)
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
