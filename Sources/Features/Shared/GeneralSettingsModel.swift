import Foundation
import Observation

@MainActor
@Observable
final class GeneralSettingsModel {
    private(set) var isLaunchAtLoginEnabled: Bool
    private(set) var launchAtLoginError: LaunchAtLoginChangeError?
    private(set) var canCheckForUpdates: Bool

    private let launchAtLoginController: any LaunchAtLoginControlling
    private let updateChecker: any UpdateChecking
    private let activityTriggeredSwitching: ActivityTriggeredSwitching

    var externalChangeResponse: ExternalChangeResponse {
        activityTriggeredSwitching.externalChangeResponse
    }

    init(
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        activityTriggeredSwitching: ActivityTriggeredSwitching
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.updateChecker = updateChecker
        self.activityTriggeredSwitching = activityTriggeredSwitching
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
            Log.error(.app, "Launch at Login could not be changed")
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginError = .registrationFailed
        }
    }

    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        activityTriggeredSwitching.setExternalChangeResponse(response)
    }

    func checkForUpdates() {
        Log.debug(.app, "Checking for updates")
        updateChecker.checkForUpdates()
        canCheckForUpdates = updateChecker.canCheckForUpdates
    }
}
