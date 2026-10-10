import Foundation
import Testing
@testable import Keyameleon

@MainActor
@Test("General settings toggles Launch at Login through Service Management seam")
func generalSettingsTogglesLaunchAtLogin() {
    let launchAtLogin = FakeLaunchAtLoginController(isEnabled: false)
    let updates = FakeUpdateChecker(canCheck: true)
    let model = GeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates,
        activityTriggeredSwitching: ProductionFactory.makeActivityTriggeredSwitching(
            setupStore: SetupModelTestSetupDecisionStore()
        ).activityTriggeredSwitching
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
    let model = GeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates,
        activityTriggeredSwitching: ProductionFactory.makeActivityTriggeredSwitching(
            setupStore: SetupModelTestSetupDecisionStore()
        ).activityTriggeredSwitching
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
    let model = GeneralSettingsModel(
        launchAtLoginController: launchAtLogin,
        updateChecker: updates,
        activityTriggeredSwitching: ProductionFactory.makeActivityTriggeredSwitching(
            setupStore: SetupModelTestSetupDecisionStore()
        ).activityTriggeredSwitching
    )

    model.checkForUpdates()

    #expect(updates.checkForUpdatesCallCount == 1)
}

@MainActor
@Test("General settings saves the External Change Response through Activity-Triggered Switching")
func generalSettingsSavesExternalChangeResponse() {
    let setupStore = SetupModelTestSetupDecisionStore()
    let switching = ProductionFactory.makeActivityTriggeredSwitching(setupStore: setupStore)
        .activityTriggeredSwitching
    let model = GeneralSettingsModel(
        launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
        updateChecker: FakeUpdateChecker(canCheck: true),
        activityTriggeredSwitching: switching
    )

    #expect(model.externalChangeResponse == .switchBack)

    model.setExternalChangeResponse(.holdUntilKeyboardChange)

    #expect(model.externalChangeResponse == .holdUntilKeyboardChange)
    #expect(switching.externalChangeResponse == .holdUntilKeyboardChange)
    #expect(setupStore.externalChangeResponse == .holdUntilKeyboardChange)
}

@MainActor
@Test("The saved External Change Response is read back after restart")
func savedExternalChangeResponseSurvivesRestart() throws {
    let suiteName = "keyameleon.tests.externalChangeResponse.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(UserDefaultsSetupDecisionStore(defaults: defaults).externalChangeResponse == .switchBack)
    UserDefaultsSetupDecisionStore(defaults: defaults).setExternalChangeResponse(.holdUntilMatch)

    let switching = ProductionFactory.makeActivityTriggeredSwitching(
        setupStore: UserDefaultsSetupDecisionStore(defaults: defaults)
    ).activityTriggeredSwitching
    #expect(switching.externalChangeResponse == .holdUntilMatch)
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
