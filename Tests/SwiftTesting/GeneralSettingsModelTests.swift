import Foundation
import Testing
@testable import Keyameleon

@MainActor
@Test("General settings toggles Launch at Login through Service Management seam")
func generalSettingsTogglesLaunchAtLogin() {
    let launchAtLogin = FakeLaunchAtLoginController(isEnabled: false)
    let updates = FakeUpdateChecker(canCheck: true)
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates
    )

    #expect(model.isLaunchAtLoginEnabled == false)

    model.setLaunchAtLoginEnabled(true)

    #expect(launchAtLogin.isEnabled)
    #expect(model.isLaunchAtLoginEnabled)
    #expect(model.launchAtLoginError == nil)
}

@MainActor
@Test("General settings surfaces Launch at Login failures")
func generalSettingsSurfacesLaunchAtLoginFailures() {
    let launchAtLogin = FakeLaunchAtLoginController(isEnabled: false, shouldFail: true)
    let updates = FakeUpdateChecker(canCheck: false)
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates
    )

    model.setLaunchAtLoginEnabled(true)

    #expect(model.isLaunchAtLoginEnabled == false)
    #expect(model.launchAtLoginError == .registrationFailed)
}

@MainActor
@Test("General settings requests a user-initiated update check")
func generalSettingsRequestsUpdateCheck() {
    let launchAtLogin = FakeLaunchAtLoginController(isEnabled: false)
    let updates = FakeUpdateChecker(canCheck: true)
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates
    )

    model.checkForUpdates()

    #expect(updates.checkForUpdatesCallCount == 1)
}

@MainActor
final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isEnabled: Bool
    private let shouldFail: Bool

    init(isEnabled: Bool, shouldFail: Bool = false) {
        self.isEnabled = isEnabled
        self.shouldFail = shouldFail
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginChangeError> {
        if shouldFail {
            return .failure(.registrationFailed)
        }
        isEnabled = enabled
        return .success(())
    }
}

@MainActor
final class FakeUpdateChecker: UpdateChecking {
    private(set) var startCallCount = 0
    private(set) var checkForUpdatesCallCount = 0
    private(set) var canCheckForUpdates: Bool

    init(canCheck: Bool) {
        canCheckForUpdates = canCheck
    }

    func start() {
        startCallCount += 1
        canCheckForUpdates = true
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }
}
