import AppKit
import XCTest
@testable import Keyameleon

final class KeyameleonApplicationTests: XCTestCase {
    @MainActor
    func testMenuContainsOpenAndQuitActions() {
        let delegate = KeyameleonApplicationDelegate()
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains { $0.hasPrefix(KeyameleonAppMetadata.switchingStatusMenuItemPrefix) })
        XCTAssertTrue(titles.contains { $0.hasPrefix(KeyameleonAppMetadata.activePhysicalKeyboardMenuItemPrefix) })
        XCTAssertTrue(titles.contains { $0.hasPrefix(KeyameleonAppMetadata.keyboardAssignmentMenuItemPrefix) })
        XCTAssertTrue(titles.contains { $0.hasPrefix(KeyameleonAppMetadata.currentInputSourceMenuItemPrefix) })
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.pauseActivityTriggeredSwitchingMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.openMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.openSystemSettingsMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.checkAgainMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.settingsMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.checkForUpdatesMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.quitMenuItemTitle))
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.openMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.openSystemSettingsMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.checkAgainMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.settingsMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.checkForUpdatesMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.quitMenuItemTitle)?.target === delegate)
        XCTAssertTrue(
            menu.item(withTitle: KeyameleonAppMetadata.pauseActivityTriggeredSwitchingMenuItemTitle)?
                .target === delegate
        )
    }

    @MainActor
    func testMenuShowsNoActivityObservedYetUntilActivation() {
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted)
        )
        let menu = delegate.makeMenu()
        let activeTitle = menu.items.first {
            $0.title.hasPrefix(KeyameleonAppMetadata.activePhysicalKeyboardMenuItemPrefix)
        }?.title

        XCTAssertEqual(
            activeTitle,
            KeyameleonAppMetadata.activePhysicalKeyboardMenuItemTitle(
                KeyameleonAppMetadata.noActivityObservedYet
            )
        )
    }

    @MainActor
    func testMenuShowsResumeWhenPaused() {
        let setupStore = ApplicationTestSetupDecisionStore()
        setupStore.setActivityTriggeredSwitchingPaused(true)
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            setupStore: setupStore
        )
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.resumeActivityTriggeredSwitchingMenuItemTitle))
        XCTAssertFalse(titles.contains(KeyameleonAppMetadata.pauseActivityTriggeredSwitchingMenuItemTitle))
        XCTAssertTrue(
            titles.contains(
                KeyameleonAppMetadata.switchingStatusMenuItemTitle(.paused)
            )
        )
    }

    @MainActor
    func testApplicationStartsUpdateCheckerOnLaunch() {
        let updates = ApplicationTestUpdateChecker()
        let delegate = KeyameleonApplicationDelegate(
            updateChecker: updates,
            startsUpdaterOnLaunch: true
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
            startsUpdaterOnLaunch: false
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(updates.startCallCount, 0)
    }

    @MainActor
    func testClosingLastWindowDoesNotTerminateApplication() {
        let delegate = KeyameleonApplicationDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testLaunchedApplicationUsesAccessoryPolicyAndAgentInfo() {
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertEqual(
            Bundle(identifier: KeyameleonAppMetadata.bundleIdentifier)?
                .object(forInfoDictionaryKey: "LSUIElement") as? Bool,
            true
        )
    }

    @MainActor
    func testSparkleInfoPlistEncodesUserApprovedUpdatePolicy() {
        let bundle = Bundle(identifier: KeyameleonAppMetadata.bundleIdentifier)
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
}
