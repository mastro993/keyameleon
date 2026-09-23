import Foundation
import Combine

@MainActor
final class KeyameleonGeneralSettingsModel: ObservableObject {
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginError: LaunchAtLoginChangeError?
    @Published private(set) var canCheckForUpdates: Bool

    private let launchAtLoginController: any LaunchAtLoginControlling
    private let updateChecker: any UpdateChecking

    init(
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.updateChecker = updateChecker
        self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        self.launchAtLoginError = nil
        self.canCheckForUpdates = updateChecker.canCheckForUpdates
    }

    func refresh() {
        isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        canCheckForUpdates = updateChecker.canCheckForUpdates
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
}
