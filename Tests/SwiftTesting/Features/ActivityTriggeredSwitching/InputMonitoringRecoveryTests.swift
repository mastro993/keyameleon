import Foundation
import Testing
@testable import Keyameleon

@Test("Permission actions follow the real Input Monitoring decision")
func permissionActionsFollowListenPermission() {
    func actions(_ permission: ListenPermissionState) -> Set<ActivityTriggeredSwitchingAction> {
        ActivityTriggeredSwitchingAction.available(
            for: permission.switchingStatus,
            listenPermission: permission,
            warnings: [],
            isPaused: false
        )
    }

    #expect(actions(.unknown) == [.requestPermission, .pause])
    #expect(actions(.denied) == [.openSystemSettings, .relaunch, .pause])
    #expect(actions(.granted) == [.pause])
}

@Test("Open System Settings targets the Input Monitoring list")
@MainActor
func openSystemSettingsTargetsInputMonitoring() {
    let harness = RecoveryHarness(permission: .denied)

    harness.recovery.openSystemSettings()

    #expect(harness.openedURLs.map(\.absoluteString) == [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
    ])
}

@Test("Relaunch quits only after the relauncher starts")
@MainActor
func relaunchQuitsOnlyWithRelauncher() {
    let failing = RecoveryHarness(permission: .denied, relauncherStarts: false)
    failing.recovery.relaunch()
    #expect(failing.terminateCount == 0)
    #expect(failing.defaults.bool(forKey: SystemInputMonitoringRecovery.relaunchKey) == false)

    let working = RecoveryHarness(permission: .denied)
    working.recovery.relaunch()
    #expect(working.terminateCount == 1)
    #expect(working.defaults.bool(forKey: SystemInputMonitoringRecovery.relaunchKey))
}

@Test("Denied after a relaunch resets the stale decision once")
@MainActor
func deniedAfterRelaunchResetsStaleDecision() async {
    let harness = RecoveryHarness(permission: .denied)
    harness.recovery.relaunch()

    #expect(await harness.recovery.resetStaleGrantAfterRelaunch())
    #expect(harness.resetCount == 1)
    #expect(harness.permission.state == .unknown)

    harness.permission.state = .denied
    #expect(await harness.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(harness.resetCount == 1)
}

@Test("A relaunch that applied the grant, or no relaunch, leaves the decision alone")
@MainActor
func grantedOrOrdinaryLaunchKeepsDecision() async {
    let ordinary = RecoveryHarness(permission: .denied)
    #expect(await ordinary.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(ordinary.resetCount == 0)

    let granted = RecoveryHarness(permission: .denied)
    granted.recovery.relaunch()
    granted.permission.state = .granted
    #expect(await granted.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(granted.resetCount == 0)
    #expect(granted.defaults.bool(forKey: SystemInputMonitoringRecovery.relaunchKey) == false)
}

@Test("A failed reset keeps the denied decision and does not ask again")
@MainActor
func failedResetDoesNotAskAgain() async {
    let harness = RecoveryHarness(permission: .denied, resetSucceeds: false)
    harness.recovery.relaunch()

    #expect(await harness.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(harness.resetCount == 1)
    #expect(harness.permission.state == .denied)
}

@MainActor
private final class RecoveryHarness {
    let permission: SetupModelTestListenPermissionProvider
    let defaults: UserDefaults
    private let relauncherStarts: Bool
    private let resetSucceeds: Bool
    private(set) var openedURLs: [URL] = []
    private(set) var terminateCount = 0
    private(set) var resetCount = 0

    private(set) lazy var recovery = SystemInputMonitoringRecovery(
        permissionProvider: permission,
        defaults: defaults,
        openURL: { [unowned self] in openedURLs.append($0) },
        startRelauncher: { [unowned self] in relauncherStarts },
        terminate: { [unowned self] in terminateCount += 1 },
        resetGrant: { [unowned self] in
            resetCount += 1
            if resetSucceeds {
                permission.state = .unknown
            }
            return resetSucceeds
        }
    )

    init(permission state: ListenPermissionState, relauncherStarts: Bool = true, resetSucceeds: Bool = true) {
        permission = SetupModelTestListenPermissionProvider(state: state)
        defaults = UserDefaults(suiteName: "InputMonitoringRecoveryTests.\(UUID().uuidString)") ?? .standard
        self.relauncherStarts = relauncherStarts
        self.resetSucceeds = resetSucceeds
    }
}
