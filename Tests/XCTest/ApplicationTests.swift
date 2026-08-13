import AppKit
import XCTest
@testable import Keyameleon

final class KeyameleonApplicationTests: XCTestCase {
    private var keyameleonBundle: Bundle? {
        Bundle(identifier: "dev.fedemas.keyameleon.development")
            ?? Bundle(identifier: "dev.fedemas.keyameleon")
    }

    private func makeSingleInstanceLock() -> KeyameleonSingleInstanceLock {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyameleonApplicationTests-\(UUID().uuidString).lock")
        guard let lock = KeyameleonSingleInstanceLock.acquire(at: url) else {
            fatalError("Could not acquire test single-instance lock")
        }
        try? FileManager.default.removeItem(at: url)
        return lock
    }

    @MainActor
    func testMenuContainsOpenAndQuitActions() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            singleInstanceLock: makeSingleInstanceLock()
        )
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains { $0.hasPrefix("Switching Status:") })
        XCTAssertTrue(titles.contains { $0.hasPrefix("Active Physical Keyboard:") })
        XCTAssertTrue(titles.contains { $0.hasPrefix("Keyboard Assignment:") })
        XCTAssertTrue(titles.contains { $0.hasPrefix("Current Input Source:") })
        XCTAssertTrue(titles.contains("Pause Activity-Triggered Switching"))
        XCTAssertTrue(titles.contains("Open Keyameleon…"))
        XCTAssertTrue(titles.contains("Open System Settings"))
        XCTAssertTrue(titles.contains("Check Again"))
        XCTAssertTrue(titles.contains("Settings…"))
        XCTAssertTrue(titles.contains("Check for Updates…"))
        XCTAssertTrue(titles.contains("Quit Keyameleon"))
        XCTAssertTrue(menu.item(withTitle: "Open Keyameleon…")?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: "Open System Settings")?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: "Check Again")?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: "Settings…")?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: "Check for Updates…")?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: "Quit Keyameleon")?.target === delegate)
        XCTAssertTrue(
            menu.item(withTitle: "Pause Activity-Triggered Switching")?
                .target === delegate
        )
    }

    @MainActor
    func testMenuShowsNoActivityObservedYetUntilActivation() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            singleInstanceLock: makeSingleInstanceLock()
        )
        let menu = delegate.makeMenu()
        let activeTitle = menu.items.first {
            $0.title.hasPrefix("Active Physical Keyboard:")
        }?.title

        XCTAssertEqual(activeTitle, "Active Physical Keyboard: No activity observed yet")
    }

    @MainActor
    func testMenuShowsResumeWhenPaused() {
        let setupStore = ApplicationTestSetupDecisionStore()
        setupStore.setActivityTriggeredSwitchingPaused(true)
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            setupStore: setupStore,
            singleInstanceLock: makeSingleInstanceLock()
        )
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains("Resume Activity-Triggered Switching"))
        XCTAssertFalse(titles.contains("Pause Activity-Triggered Switching"))
        XCTAssertTrue(titles.contains("Switching Status: Paused"))
    }

    @MainActor
    func testMenuBarIconPresentationMapsEveryStatusMark() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            singleInstanceLock: makeSingleInstanceLock()
        )
        let expected: [(MenuBarIconMark, String, String)] = [
            (.ready, "keyboard", "Keyameleon"),
            (.permissionRequired, "keyboard.badge.ellipsis", "Keyameleon — Permission Required"),
            (.temporarilyUnavailable, "moon.zzz", "Keyameleon — Temporarily Unavailable"),
            (.paused, "pause.circle", "Keyameleon — Paused"),
            (.warning, "exclamationmark.triangle", "Keyameleon — Action needed")
        ]

        for (mark, symbolName, accessibilityDescription) in expected {
            XCTAssertEqual(delegate.systemSymbolName(for: mark), symbolName)
            XCTAssertEqual(
                delegate.menuBarIconAccessibilityDescription(for: mark),
                accessibilityDescription
            )
        }
    }

    @MainActor
    func testMenuShowsDismissibleUncleanExitNoticeAndReviewAction() {
        let uncleanExitState = ApplicationTestUncleanExitStateStore(hasNotice: true)
        let delegate = KeyameleonApplicationDelegate(
            uncleanExitStateStore: uncleanExitState,
            singleInstanceLock: makeSingleInstanceLock()
        )
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains("Keyameleon did not exit cleanly."))
        XCTAssertTrue(titles.contains("Review Diagnostics…"))
        XCTAssertTrue(titles.contains("Dismiss Diagnostics Notice"))
        XCTAssertTrue(
            menu.item(withTitle: "Review Diagnostics…")?.target === delegate
        )
        XCTAssertTrue(
            menu.item(withTitle: "Dismiss Diagnostics Notice")?.target === delegate
        )
    }

    @MainActor
    func testApplicationStartsUpdateCheckerOnLaunch() {
        let updates = ApplicationTestUpdateChecker()
        let delegate = KeyameleonApplicationDelegate(
            updateChecker: updates,
            startsUpdaterOnLaunch: true,
            singleInstanceLock: makeSingleInstanceLock()
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(updates.startCallCount, 1)
    }

    @MainActor
    func testApplicationCanSkipUpdateCheckerOnLaunch() {
        let updates = ApplicationTestUpdateChecker()
        let delegate = KeyameleonApplicationDelegate(
            updateChecker: updates,
            startsUpdaterOnLaunch: false,
            singleInstanceLock: makeSingleInstanceLock()
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(updates.startCallCount, 0)
    }

    @MainActor
    func testClosingLastWindowDoesNotTerminateApplication() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            singleInstanceLock: makeSingleInstanceLock()
        )

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testReopenDoesNotReactivateOrOpenTheRunningApplication() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            singleInstanceLock: makeSingleInstanceLock()
        )

        XCTAssertFalse(
            delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        )
    }

    @MainActor
    func testLaunchedApplicationUsesAccessoryPolicyAndAgentInfo() {
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertEqual(
            keyameleonBundle?
                .object(forInfoDictionaryKey: "LSUIElement") as? Bool,
            true
        )
        XCTAssertEqual(
            keyameleonBundle?
                .object(forInfoDictionaryKey: "LSMultipleInstancesProhibited") as? Bool,
            true
        )
    }

    @MainActor
    func testSparkleInfoPlistEncodesUserApprovedUpdatePolicy() {
        let bundle = keyameleonBundle
        XCTAssertEqual(
            bundle?.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            KeyameleonUpdatePolicy.feedURLString
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
        XCTAssertEqual(
            bundle?.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? Int,
            Int(KeyameleonUpdatePolicy.minimumCheckInterval)
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool, false)
    }
}

@MainActor
private final class ApplicationTestUpdateChecker: UpdateChecking {
    private(set) var startCallCount = 0
    var canCheckForUpdates = false

    func start() {
        startCallCount += 1
        canCheckForUpdates = true
    }

    func checkForUpdates() {}
}

@MainActor
private final class ApplicationTestListenPermissionProvider: ListenPermissionProviding {
    var state: ListenPermissionState

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        state
    }

    func requestListenPermission() -> Bool {
        state == .granted
    }
}

@MainActor
private final class ApplicationTestSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup = false
    private(set) var hasCompletedGuidedSetup = true
    private(set) var guidedSetupStep: GuidedSetupStep = .assignments
    private(set) var isActivityTriggeredSwitchingPaused = false
    private(set) var hasEvaluatedBuiltInIdentityMigration = false

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasStartedGuidedSetup = true
        hasCompletedGuidedSetup = true
        guidedSetupStep = .assignments
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }
}

@MainActor
private final class ApplicationTestUncleanExitStateStore: UncleanExitStateStoring {
    private(set) var hasPendingUncleanExitNotice: Bool

    init(hasNotice: Bool) {
        hasPendingUncleanExitNotice = hasNotice
    }

    func beginLaunch() {}

    func markCleanTermination() {}

    func dismissUncleanExitNotice() {
        hasPendingUncleanExitNotice = false
    }

    func resetForUITesting() {
        hasPendingUncleanExitNotice = false
    }
}
