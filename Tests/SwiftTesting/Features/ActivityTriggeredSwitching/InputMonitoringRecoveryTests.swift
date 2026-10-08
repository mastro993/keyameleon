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

    let working = RecoveryHarness(permission: .denied)
    working.recovery.relaunch()
    #expect(working.terminateCount == 1)
}

@Test("Denied in a process opened by the relauncher resets the stale decision once")
@MainActor
func deniedAfterRelaunchResetsStaleDecision() async {
    let harness = RecoveryHarness(permission: .denied, relaunched: true)

    #expect(await harness.recovery.resetStaleGrantAfterRelaunch())
    #expect(harness.resetCount == 1)
    #expect(harness.permission.state == .unknown)

    harness.permission.state = .denied
    #expect(await harness.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(harness.resetCount == 1)
}

@Test("A manual launch never resets, even after a relaunch that failed to reopen")
@MainActor
func manualLaunchNeverResets() async {
    let previous = RecoveryHarness(permission: .denied)
    previous.recovery.relaunch()
    #expect(previous.terminateCount == 1)

    // The reopen failed; the person opens Keyameleon later from Finder.
    let manual = RecoveryHarness(permission: .denied)
    #expect(await manual.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(manual.resetCount == 0)
    #expect(manual.permission.state == .denied)
}

@Test("A relaunch that applied the grant leaves the decision alone")
@MainActor
func grantedRelaunchKeepsDecision() async {
    let harness = RecoveryHarness(permission: .granted, relaunched: true)
    #expect(await harness.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(harness.resetCount == 0)
}

@Test("A failed reset keeps the denied decision and does not ask again")
@MainActor
func failedResetDoesNotAskAgain() async {
    let harness = RecoveryHarness(permission: .denied, relaunched: true, resetSucceeds: false)

    #expect(await harness.recovery.resetStaleGrantAfterRelaunch() == false)
    #expect(harness.resetCount == 1)
    #expect(harness.permission.state == .denied)
}

@MainActor
private final class RecoveryHarness {
    let permission: SetupModelTestListenPermissionProvider
    private let launchArguments: [String]
    private let relauncherStarts: Bool
    private let resetSucceeds: Bool
    private(set) var openedURLs: [URL] = []
    private(set) var terminateCount = 0
    private(set) var resetCount = 0

    private(set) lazy var recovery = SystemInputMonitoringRecovery(
        permissionProvider: permission,
        launchArguments: launchArguments,
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

    init(
        permission state: ListenPermissionState,
        relaunched: Bool = false,
        relauncherStarts: Bool = true,
        resetSucceeds: Bool = true
    ) {
        permission = SetupModelTestListenPermissionProvider(state: state)
        launchArguments = ["Keyameleon"] + (relaunched ? [SystemInputMonitoringRecovery.relaunchArgument] : [])
        self.relauncherStarts = relauncherStarts
        self.resetSucceeds = resetSucceeds
    }
}
