import Foundation
import Combine

@MainActor
final class KeyameleonGeneralSettingsModel: ObservableObject {
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginError: LaunchAtLoginChangeError?
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var notificationAuthorizationState: OperationalNotificationAuthorizationState

    private let launchAtLoginController: any LaunchAtLoginControlling
    private let updateChecker: any UpdateChecking
    private let operationalNotifications: OperationalNotifications
    private let notificationSettingsOpener: any NotificationSettingsOpening
    private var notificationObserverID: UUID?

    init(
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        operationalNotifications: OperationalNotifications? = nil,
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationSettingsOpener: any NotificationSettingsOpening =
            NoOpNotificationSettingsOpener()
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.updateChecker = updateChecker
        let notifications = operationalNotifications ?? OperationalNotifications(
            provider: operationalNotificationProvider
        )
        self.operationalNotifications = notifications
        self.notificationSettingsOpener = notificationSettingsOpener
        self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        self.launchAtLoginError = nil
        self.canCheckForUpdates = updateChecker.canCheckForUpdates
        self.notificationAuthorizationState = notifications.authorizationState
        notificationObserverID = notifications.observe { [weak self] in
            self?.notificationAuthorizationState = notifications.authorizationState
        }
    }

    func refresh() {
        isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        canCheckForUpdates = updateChecker.canCheckForUpdates
        refreshNotificationAuthorization()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        switch launchAtLoginController.setEnabled(enabled) {
        case .success:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginError = nil
        case .failure:
            KeyameleonLog.error(.app, "Launch at Login could not be changed")
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginError = .registrationFailed
        }
    }

    func checkForUpdates() {
        KeyameleonLog.debug(.app, "Checking for updates")
        updateChecker.checkForUpdates()
        canCheckForUpdates = updateChecker.canCheckForUpdates
    }

    func requestOperationalNotificationAuthorization() {
        operationalNotifications.requestAlertAuthorization()
    }

    func openNotificationSettings() {
        notificationSettingsOpener.openNotificationSettings()
    }

    private func refreshNotificationAuthorization() {
        operationalNotifications.refreshAuthorization()
    }
}
