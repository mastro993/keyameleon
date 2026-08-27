import AppKit
import CryptoKit
import Foundation
import UserNotifications

enum OperationalNotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized

    var canSend: Bool {
        self == .authorized
    }
}

enum OperationalNotification: Equatable, Sendable {
    case listenPermissionRevoked
    case unavailableKeyboardAssignment
}

enum OperationalNotificationEpisode: Hashable, Sendable {
    case listenPermissionRevoked
    case unavailableKeyboardAssignment(
        physicalKeyboardID: PhysicalKeyboardRecordID,
        inputSourceIdentifier: String
    )

    /// Persistence uses a one-way token. Physical Keyboard Identity and Input Source identifiers stay out of UserDefaults.
    var storageKey: String {
        let material: String
        switch self {
        case .listenPermissionRevoked:
            material = "listen-permission-revoked"
        case let .unavailableKeyboardAssignment(physicalKeyboardID, inputSourceIdentifier):
            material = "unavailable-keyboard-assignment|\(physicalKeyboardID.rawValue)|\(inputSourceIdentifier)"
        }

        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

@MainActor
protocol OperationalNotificationCenter: AnyObject {
    func getAuthorizationStatus(
        onChange: @escaping @MainActor (UNAuthorizationStatus) -> Void
    )
    func requestAuthorization(
        options: UNAuthorizationOptions,
        onChange: @escaping @MainActor (Bool) -> Void
    )
    func add(_ request: UNNotificationRequest)
}

@MainActor
final class SystemOperationalNotificationCenter: OperationalNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func getAuthorizationStatus(
        onChange: @escaping @MainActor (UNAuthorizationStatus) -> Void
    ) {
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                onChange(status)
            }
        }
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        center.requestAuthorization(options: options) { granted, _ in
            Task { @MainActor in
                onChange(granted)
            }
        }
    }

    func add(_ request: UNNotificationRequest) {
        center.add(request)
    }
}

@MainActor
protocol OperationalNotificationProviding: AnyObject {
    var authorizationState: OperationalNotificationAuthorizationState { get }

    func refreshAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    )
    func requestAlertAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    )
    func send(_ notification: OperationalNotification)
}

@MainActor
final class SystemOperationalNotificationProvider: OperationalNotificationProviding {
    private let center: any OperationalNotificationCenter
    private(set) var authorizationState: OperationalNotificationAuthorizationState = .unknown

    init(
        center: any OperationalNotificationCenter = SystemOperationalNotificationCenter()
    ) {
        self.center = center
    }

    func refreshAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        center.getAuthorizationStatus { [weak self] status in
            guard let self else {
                return
            }

            let state = Self.authorizationState(for: status)
            self.authorizationState = state
            onChange(state)
        }
    }

    func requestAlertAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        // Alert authorization only. Sound and icon badge authorization are intentionally omitted.
        center.requestAuthorization(options: [.alert]) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAuthorization(onChange: onChange)
            }
        }
    }

    func send(_ notification: OperationalNotification) {
        guard authorizationState.canSend else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Keyameleon needs attention"
        content.body = notificationBody(for: notification)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func notificationBody(for notification: OperationalNotification) -> String {
        switch notification {
        case .listenPermissionRevoked:
            "Input Monitoring permission was revoked. Open System Settings to restore Activity-Triggered Switching."
        case .unavailableKeyboardAssignment:
            "A Keyboard Assignment is unavailable. Open Keyameleon to change or remove it."
        }
    }

    nonisolated private static func authorizationState(
        for status: UNAuthorizationStatus
    ) -> OperationalNotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional:
            .authorized
        @unknown default:
            .unknown
        }
    }
}

@MainActor
final class NoOpOperationalNotificationProvider: OperationalNotificationProviding {
    private(set) var authorizationState: OperationalNotificationAuthorizationState = .unknown

    func refreshAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        onChange(authorizationState)
    }

    func requestAlertAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        onChange(authorizationState)
    }

    func send(_ notification: OperationalNotification) {}
}

@MainActor
protocol OperationalNotificationEpisodeStoring: AnyObject {
    var hasEverObservedGrantedListenPermission: Bool { get }

    func markGrantedListenPermissionObserved()
    func begin(_ episode: OperationalNotificationEpisode)
    func isActive(_ episode: OperationalNotificationEpisode) -> Bool
    func hasSentNotification(for episode: OperationalNotificationEpisode) -> Bool
    func markNotificationSent(for episode: OperationalNotificationEpisode)
    func end(_ episode: OperationalNotificationEpisode)
}

@MainActor
final class InMemoryOperationalNotificationEpisodeStore: OperationalNotificationEpisodeStoring {
    private(set) var hasEverObservedGrantedListenPermission = false
    private var activeEpisodes: Set<String> = []
    private var sentEpisodes: Set<String> = []

    func markGrantedListenPermissionObserved() {
        hasEverObservedGrantedListenPermission = true
    }

    func begin(_ episode: OperationalNotificationEpisode) {
        activeEpisodes.insert(episode.storageKey)
    }

    func isActive(_ episode: OperationalNotificationEpisode) -> Bool {
        activeEpisodes.contains(episode.storageKey)
    }

    func hasSentNotification(for episode: OperationalNotificationEpisode) -> Bool {
        sentEpisodes.contains(episode.storageKey)
    }

    func markNotificationSent(for episode: OperationalNotificationEpisode) {
        sentEpisodes.insert(episode.storageKey)
    }

    func end(_ episode: OperationalNotificationEpisode) {
        activeEpisodes.remove(episode.storageKey)
        sentEpisodes.remove(episode.storageKey)
    }
}

@MainActor
final class UserDefaultsOperationalNotificationEpisodeStore: OperationalNotificationEpisodeStoring {
    private enum Key {
        static let hasEverObservedGrantedListenPermission =
            "keyameleon.notifications.listenPermissionGranted"
        static let activeEpisodes = "keyameleon.notifications.activeEpisodes"
        static let sentEpisodes = "keyameleon.notifications.sentEpisodes"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasEverObservedGrantedListenPermission: Bool {
        defaults.bool(forKey: Key.hasEverObservedGrantedListenPermission)
    }

    func markGrantedListenPermissionObserved() {
        defaults.set(true, forKey: Key.hasEverObservedGrantedListenPermission)
    }

    func begin(_ episode: OperationalNotificationEpisode) {
        var episodes = values(forKey: Key.activeEpisodes)
        episodes.insert(episode.storageKey)
        defaults.set(episodes.sorted(), forKey: Key.activeEpisodes)
    }

    func isActive(_ episode: OperationalNotificationEpisode) -> Bool {
        values(forKey: Key.activeEpisodes).contains(episode.storageKey)
    }

    func hasSentNotification(for episode: OperationalNotificationEpisode) -> Bool {
        values(forKey: Key.sentEpisodes).contains(episode.storageKey)
    }

    func markNotificationSent(for episode: OperationalNotificationEpisode) {
        var episodes = values(forKey: Key.sentEpisodes)
        episodes.insert(episode.storageKey)
        defaults.set(episodes.sorted(), forKey: Key.sentEpisodes)
    }

    func end(_ episode: OperationalNotificationEpisode) {
        remove(episode.storageKey, fromKey: Key.activeEpisodes)
        remove(episode.storageKey, fromKey: Key.sentEpisodes)
    }

    private func values(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func remove(_ value: String, fromKey key: String) {
        var values = values(forKey: key)
        values.remove(value)
        defaults.set(values.sorted(), forKey: key)
    }
}

@MainActor
protocol NotificationSetupDecisionStoring: AnyObject {
    var hasOfferedOperationalNotificationSetup: Bool { get }

    func markOperationalNotificationSetupOffered()
}

@MainActor
final class InMemoryNotificationSetupDecisionStore: NotificationSetupDecisionStoring {
    private(set) var hasOfferedOperationalNotificationSetup = false

    func markOperationalNotificationSetupOffered() {
        hasOfferedOperationalNotificationSetup = true
    }
}

@MainActor
final class UserDefaultsNotificationSetupDecisionStore: NotificationSetupDecisionStoring {
    private let defaults: UserDefaults
    private let key = "keyameleon.notifications.setup.offered"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasOfferedOperationalNotificationSetup: Bool {
        defaults.bool(forKey: key)
    }

    func markOperationalNotificationSetupOffered() {
        defaults.set(true, forKey: key)
    }
}

@MainActor
protocol NotificationSettingsOpening: AnyObject {
    func openNotificationSettings()
}

@MainActor
final class NSWorkspaceNotificationSettingsOpener: NotificationSettingsOpening {
    func openNotificationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class NoOpNotificationSettingsOpener: NotificationSettingsOpening {
    func openNotificationSettings() {}
}

/// Deep module for bounded Operational Notification authorization and episodes.
///
/// Activity-Triggered Switching supplies internal product conditions. This
/// module owns persistence, episode recovery, setup-offer gating, pause
/// suppression, and delivery.
@MainActor
final class OperationalNotifications {
    private let provider: any OperationalNotificationProviding
    private let episodeStore: any OperationalNotificationEpisodeStoring
    private let setupStore: any NotificationSetupDecisionStoring
    private var isAuthorizationRequestInFlight = false
    private var isPaused = false
    private var activeWarnings: [SwitchingWarning] = []
    private var observers: [UUID: @MainActor () -> Void] = [:]

    private(set) var authorizationState: OperationalNotificationAuthorizationState
    private(set) var shouldOfferSetup = false

    init(
        provider: any OperationalNotificationProviding = NoOpOperationalNotificationProvider(),
        episodeStore: any OperationalNotificationEpisodeStoring =
            InMemoryOperationalNotificationEpisodeStore(),
        setupStore: any NotificationSetupDecisionStoring = InMemoryNotificationSetupDecisionStore()
    ) {
        self.provider = provider
        self.episodeStore = episodeStore
        self.setupStore = setupStore
        authorizationState = provider.authorizationState
        updateSetupOffer(listenPermission: .unknown, hasKeyboardAssignment: false)
    }

    @discardableResult
    func observe(_ observer: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    func refreshAuthorization() {
        provider.refreshAuthorization { [weak self] state in
            guard let self else {
                return
            }

            authorizationState = state
            sendPendingNotifications()
            publish()
        }
    }

    func requestAlertAuthorization() {
        guard authorizationState == .notDetermined,
              !isAuthorizationRequestInFlight
        else {
            return
        }

        isAuthorizationRequestInFlight = true
        setupStore.markOperationalNotificationSetupOffered()
        shouldOfferSetup = false
        provider.requestAlertAuthorization { [weak self] state in
            guard let self else {
                return
            }

            isAuthorizationRequestInFlight = false
            authorizationState = state
            sendPendingNotifications()
            publish()
        }
        publish()
    }

    func dismissSetupOffer() {
        guard shouldOfferSetup else {
            return
        }

        setupStore.markOperationalNotificationSetupOffered()
        shouldOfferSetup = false
        publish()
    }

    func update(
        listenPermission: ListenPermissionState,
        warnings: [SwitchingWarning],
        hasKeyboardAssignment: Bool,
        paused: Bool
    ) {
        let previousWarnings = activeWarnings
        isPaused = paused
        activeWarnings = warnings

        updateListenPermissionEpisode(listenPermission)
        updateUnavailableAssignmentEpisodes(
            previousWarnings: previousWarnings,
            currentWarnings: warnings
        )
        updateSetupOffer(
            listenPermission: listenPermission,
            hasKeyboardAssignment: hasKeyboardAssignment
        )
        sendPendingNotifications()
        publish()
    }

    private func updateListenPermissionEpisode(_ permission: ListenPermissionState) {
        let episode = OperationalNotificationEpisode.listenPermissionRevoked
        switch permission {
        case .granted:
            episodeStore.markGrantedListenPermissionObserved()
            episodeStore.end(episode)
        case .denied where episodeStore.hasEverObservedGrantedListenPermission:
            episodeStore.begin(episode)
        case .unknown, .denied:
            break
        }
    }

    private func updateUnavailableAssignmentEpisodes(
        previousWarnings: [SwitchingWarning],
        currentWarnings: [SwitchingWarning]
    ) {
        let currentEpisodes = Set(
            currentWarnings.compactMap { warning -> OperationalNotificationEpisode? in
                guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause,
                      let inputSourceIdentifier = warning.inputSourceIdentifier
                else {
                    return nil
                }

                return .unavailableKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: inputSourceIdentifier
                )
            }
        )

        let previousEpisodes = Set(
            previousWarnings.compactMap { warning -> OperationalNotificationEpisode? in
                guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause,
                      let inputSourceIdentifier = warning.inputSourceIdentifier
                else {
                    return nil
                }

                return .unavailableKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: inputSourceIdentifier
                )
            }
        )

        for episode in previousEpisodes.subtracting(currentEpisodes) {
            episodeStore.end(episode)
        }
        for episode in currentEpisodes {
            episodeStore.begin(episode)
        }
    }

    private func updateSetupOffer(
        listenPermission: ListenPermissionState,
        hasKeyboardAssignment: Bool
    ) {
        shouldOfferSetup = !setupStore.hasOfferedOperationalNotificationSetup
            && listenPermission == .granted
            && authorizationState == .notDetermined
            && hasKeyboardAssignment
    }

    private func sendPendingNotifications() {
        guard !isPaused, authorizationState.canSend else {
            return
        }

        sendIfNeeded(
            episode: .listenPermissionRevoked,
            notification: .listenPermissionRevoked
        )

        for warning in activeWarnings {
            guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause,
                  let inputSourceIdentifier = warning.inputSourceIdentifier
            else {
                continue
            }

            sendIfNeeded(
                episode: .unavailableKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: inputSourceIdentifier
                ),
                notification: .unavailableKeyboardAssignment
            )
        }
    }

    private func sendIfNeeded(
        episode: OperationalNotificationEpisode,
        notification: OperationalNotification
    ) {
        guard episodeStore.isActive(episode),
              !episodeStore.hasSentNotification(for: episode)
        else {
            return
        }

        episodeStore.markNotificationSent(for: episode)
        provider.send(notification)
    }

    private func publish() {
        for observer in observers.values {
            observer()
        }
    }
}
