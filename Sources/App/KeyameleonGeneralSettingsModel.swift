import Foundation
import Combine

@MainActor
final class KeyameleonGeneralSettingsModel: ObservableObject {
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginErrorMessage: String?
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
        self.launchAtLoginErrorMessage = nil
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
            launchAtLoginErrorMessage = nil
        case .failure:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginErrorMessage = KeyameleonAppMetadata.launchAtLoginErrorMessage
        }
    }

    func checkForUpdates() {
        updateChecker.checkForUpdates()
        canCheckForUpdates = updateChecker.canCheckForUpdates
    }
}
