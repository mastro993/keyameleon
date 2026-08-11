import Foundation
import Testing
import UserNotifications
@testable import Keyameleon

@MainActor
@Test("First Keyboard Assignment offers optional alert authorization after listen permission succeeds")
func firstKeyboardAssignmentOffersOptionalAlertAuthorizationAfterListenPermissionSucceeds() {
    let listenPermission = SetupModelTestListenPermissionProvider(
        state: .unknown,
        stateAfterRequest: .granted
    )
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .notDetermined
    )
    let model = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider
    )

    model.refreshPermission()
    #expect(!model.shouldOfferOperationalNotificationSetup)
    model.requestPermission()
    #expect(model.switchingStatus == .ready)

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let assignedModel = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider,
        physicalKeyboardDiscoverer: discoverer
    )
    assignedModel.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 1201)))
    assignedModel.setKeyboardAssignment(
        assignedModel.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )

    #expect(assignedModel.shouldOfferOperationalNotificationSetup)
    #expect(notificationProvider.requestAuthorizationCount == 0)

    assignedModel.requestOperationalNotificationAuthorization()
    #expect(notificationProvider.requestAuthorizationCount == 1)
    assignedModel.requestOperationalNotificationAuthorization()
    #expect(notificationProvider.requestAuthorizationCount == 1)
}

@MainActor
@Test("Listen permission revocation sends one notification per episode across restart")
func listenPermissionRevocationSendsOneNotificationPerEpisodeAcrossRestart() {
    let listenPermission = SetupModelTestListenPermissionProvider(state: .granted)
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .authorized
    )
    let episodeStore = InMemoryOperationalNotificationEpisodeStore()
    let setupStore = SetupModelTestSetupDecisionStore()
    let model = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider,
        notificationEpisodeStore: episodeStore,
        setupStore: setupStore
    )

    model.refreshPermission()
    listenPermission.state = .unknown
    model.refreshPermission()
    #expect(notificationProvider.sentNotifications.isEmpty)
    listenPermission.state = .denied
    model.refreshPermission()
    model.refreshPermission()

    #expect(notificationProvider.sentNotifications == [.listenPermissionRevoked])

    let restartedModel = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider,
        notificationEpisodeStore: episodeStore,
        setupStore: setupStore
    )
    restartedModel.refreshPermission()
    #expect(notificationProvider.sentNotifications == [.listenPermissionRevoked])

    listenPermission.state = .granted
    restartedModel.refreshPermission()
    listenPermission.state = .denied
    restartedModel.refreshPermission()

    #expect(
        notificationProvider.sentNotifications == [
            .listenPermissionRevoked,
            .listenPermissionRevoked,
        ]
    )
}

@MainActor
@Test("Unavailable Keyboard Assignment sends one notification and pause blocks it")
func unavailableKeyboardAssignmentSendsOneNotificationAndPauseBlocksIt() {
    let listenPermission = SetupModelTestListenPermissionProvider(state: .granted)
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .authorized
    )
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.setActivityTriggeredSwitchingPaused(true)
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider,
        notificationEpisodeStore: InMemoryOperationalNotificationEpisodeStore(),
        setupStore: setupStore,
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.other", name: "Other"),
            ]
        )
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 1202)))
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.missing"
    )
    model.refreshPermission()

    #expect(notificationProvider.sentNotifications.isEmpty)
    #expect(model.activeWarnings.count == 1)

    model.resumeActivityTriggeredSwitching()
    #expect(notificationProvider.sentNotifications == [.unavailableKeyboardAssignment])
    model.refreshPermission()
    #expect(notificationProvider.sentNotifications == [.unavailableKeyboardAssignment])
}

@MainActor
@Test("Listen permission recovery while Paused ends the notification episode")
func listenPermissionRecoveryWhilePausedEndsNotificationEpisode() {
    let listenPermission = SetupModelTestListenPermissionProvider(state: .granted)
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .authorized
    )
    let setupStore = SetupModelTestSetupDecisionStore()
    setupStore.setActivityTriggeredSwitchingPaused(true)
    let model = makeOperationalNotificationModel(
        listenPermission: listenPermission,
        notificationProvider: notificationProvider,
        setupStore: setupStore
    )

    model.refreshPermission()
    listenPermission.state = .denied
    model.refreshPermission()
    #expect(notificationProvider.sentNotifications.isEmpty)

    listenPermission.state = .granted
    model.resumeActivityTriggeredSwitching()

    #expect(notificationProvider.sentNotifications.isEmpty)
}

@MainActor
@Test("Notification denial does not block Activity-Triggered Switching")
func notificationDenialDoesNotBlockActivityTriggeredSwitching() {
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other")
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeOperationalNotificationModel(
        listenPermission: SetupModelTestListenPermissionProvider(state: .granted),
        notificationProvider: TestOperationalNotificationProvider(
            authorizationState: .denied
        ),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.other", name: "Other"),
            ]
        ),
        inputSourceSelector: selector
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 1203)))
    model.setKeyboardAssignment(
        model.physicalKeyboards[0].id,
        inputSourceIdentifier: "com.example.us"
    )
    model.handlePhysicalKeyboardEvent(
        PhysicalKeyboardEvent(serviceID: 1203, kind: .press)
    )

    #expect(selector.selectCount == 1)
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.us")
}

@MainActor
@Test("General settings shows notification state and opens System Settings")
func generalSettingsShowsNotificationStateAndOpensSystemSettings() {
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .denied
    )
    let settingsOpener = TestNotificationSettingsOpener()
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
        updateChecker: FakeUpdateChecker(canCheck: true),
        operationalNotificationProvider: notificationProvider,
        notificationSettingsOpener: settingsOpener
    )

    model.refresh()
    #expect(model.notificationAuthorizationState == .denied)
    model.openNotificationSettings()
    #expect(settingsOpener.openCount == 1)

    model.requestOperationalNotificationAuthorization()
    #expect(notificationProvider.requestAuthorizationCount == 0)
}

@MainActor
@Test("General authorization change can refresh operational notification delivery")
func generalAuthorizationChangeCanRefreshOperationalNotificationDelivery() {
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .notDetermined
    )
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
        updateChecker: FakeUpdateChecker(canCheck: true),
        operationalNotificationProvider: notificationProvider
    )
    var changeCount = 0
    model.onNotificationAuthorizationChange = {
        changeCount += 1
    }

    model.requestOperationalNotificationAuthorization()

    #expect(model.notificationAuthorizationState == .authorized)
    #expect(changeCount == 1)
}

@MainActor
@Test("Operational notification episode state persists across store reload")
func operationalNotificationEpisodeStatePersistsAcrossStoreReload() {
    let suiteName = "KeyameleonTests.notifications.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let episode = OperationalNotificationEpisode.unavailableKeyboardAssignment(
        physicalKeyboardID: PhysicalKeyboardRecordID(rawValue: "hardware-episode-test"),
        inputSourceIdentifier: "com.example.persisted"
    )
    let store = UserDefaultsOperationalNotificationEpisodeStore(defaults: defaults)
    store.markGrantedListenPermissionObserved()
    store.begin(episode)
    store.markNotificationSent(for: episode)

    let reloadedStore = UserDefaultsOperationalNotificationEpisodeStore(defaults: defaults)
    #expect(reloadedStore.hasEverObservedGrantedListenPermission)
    #expect(reloadedStore.isActive(episode))
    #expect(reloadedStore.hasSentNotification(for: episode))
    #expect(!episode.storageKey.contains("hardware-episode-test"))
    #expect(!episode.storageKey.contains("com.example.persisted"))

    reloadedStore.end(episode)
    let recoveredStore = UserDefaultsOperationalNotificationEpisodeStore(defaults: defaults)
    #expect(!recoveredStore.isActive(episode))
    #expect(!recoveredStore.hasSentNotification(for: episode))
}

@MainActor
@Test("System notifications request alerts only and set no sound or badge")
func systemNotificationsRequestAlertsOnlyAndSetNoSoundOrBadge() {
    let center = TestOperationalNotificationCenter(status: .authorized)
    let provider = SystemOperationalNotificationProvider(center: center)
    provider.refreshAuthorization { _ in }
    provider.requestAlertAuthorization { _ in }
    provider.send(.listenPermissionRevoked)

    #expect(center.requestedOptions == [.alert])
    #expect(center.requests.count == 1)
    #expect(center.requests[0].content.sound == nil)
    #expect(center.requests[0].content.badge == nil)
}

@MainActor
@Test("Replacing a saved Physical Keyboard starts the new unavailable episode")
func replacingSavedPhysicalKeyboardStartsNewUnavailableEpisode() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let notificationProvider = TestOperationalNotificationProvider(
        authorizationState: .authorized
    )
    let model = makeOperationalNotificationModel(
        listenPermission: SetupModelTestListenPermissionProvider(state: .granted),
        notificationProvider: notificationProvider,
        physicalKeyboardRecordStore: recordStore,
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.other", name: "Other"),
            ]
        )
    )

    model.refreshPermission()
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 1210,
                identity: "macos.keyboard.old-notification",
                serialNumber: "serial-old-notification"
            )
        )
    )
    let oldID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(oldID, inputSourceIdentifier: "com.example.missing")
    discoverer.emit(.disconnected(serviceID: 1210))
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 1211,
                identity: "macos.keyboard.new-notification",
                serialNumber: "serial-new-notification"
            )
        )
    )
    let newID = model.physicalKeyboards.first { $0.connectionState == .connected }!.id

    model.replaceSavedPhysicalKeyboard(oldID, with: newID)

    #expect(
        notificationProvider.sentNotifications == [
            .unavailableKeyboardAssignment,
            .unavailableKeyboardAssignment,
        ]
    )
    #expect(model.activeWarnings.count == 1)
    #expect(model.activeWarnings[0].cause == .unavailableKeyboardAssignment(newID))
}

@MainActor
private func makeOperationalNotificationModel(
    listenPermission: SetupModelTestListenPermissionProvider,
    notificationProvider: TestOperationalNotificationProvider,
    notificationEpisodeStore: any OperationalNotificationEpisodeStoring =
        InMemoryOperationalNotificationEpisodeStore(),
    notificationSetupStore: any NotificationSetupDecisionStoring =
        InMemoryNotificationSetupDecisionStore(),
    setupStore: SetupModelTestSetupDecisionStore = SetupModelTestSetupDecisionStore(),
    physicalKeyboardRecordStore: InMemoryPhysicalKeyboardRecordStore =
        InMemoryPhysicalKeyboardRecordStore(),
    physicalKeyboardDiscoverer: SetupModelTestPhysicalKeyboardDiscoverer =
        SetupModelTestPhysicalKeyboardDiscoverer(),
    inputSourceProvider: SetupModelTestInputSourceProvider = SetupModelTestInputSourceProvider(
        inputSources: []
    ),
    inputSourceSelector: SetupModelTestInputSourceSelector = SetupModelTestInputSourceSelector()
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: listenPermission,
        setupStore: setupStore,
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: physicalKeyboardDiscoverer,
        inputSourceProvider: inputSourceProvider,
        inputSourceSelector: inputSourceSelector,
        physicalKeyboardRecordStore: physicalKeyboardRecordStore,
        operationalNotificationProvider: notificationProvider,
        notificationEpisodeStore: notificationEpisodeStore,
        notificationSetupStore: notificationSetupStore
    )
}

@MainActor
private final class TestOperationalNotificationProvider: OperationalNotificationProviding {
    var authorizationState: OperationalNotificationAuthorizationState
    private(set) var requestAuthorizationCount = 0
    private(set) var sentNotifications: [OperationalNotification] = []

    init(authorizationState: OperationalNotificationAuthorizationState) {
        self.authorizationState = authorizationState
    }

    func refreshAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        onChange(authorizationState)
    }

    func requestAlertAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        requestAuthorizationCount += 1
        authorizationState = .authorized
        onChange(authorizationState)
    }

    func send(_ notification: OperationalNotification) {
        sentNotifications.append(notification)
    }
}

@MainActor
private final class TestNotificationSettingsOpener: NotificationSettingsOpening {
    private(set) var openCount = 0

    func openNotificationSettings() {
        openCount += 1
    }
}

@MainActor
private final class TestOperationalNotificationCenter: OperationalNotificationCenter {
    var status: UNAuthorizationStatus
    private(set) var requestedOptions: UNAuthorizationOptions?
    private(set) var requests: [UNNotificationRequest] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func getAuthorizationStatus(
        onChange: @escaping @MainActor (UNAuthorizationStatus) -> Void
    ) {
        onChange(status)
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        requestedOptions = options
        onChange(true)
    }

    func add(_ request: UNNotificationRequest) {
        requests.append(request)
    }
}
