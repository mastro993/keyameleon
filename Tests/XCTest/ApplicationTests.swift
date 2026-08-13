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
    func testStatusItemOpensTransient360PointPanelAndCloses() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = KeyameleonApplicationDelegate(
            permissionProvider: permission,
            setupStore: ApplicationTestSetupDecisionStore(),
            startsUpdaterOnLaunch: false,
            singleInstanceLock: makeSingleInstanceLock()
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        let anchor = MenuBarPanelTestAnchorWindow()
        defer {
            delegate.closeMenuBarPanel()
            anchor.close()
        }

        XCTAssertNil(delegate.menuBarStatusItem?.menu)
        XCTAssertEqual(
            delegate.menuBarStatusItem?.button?.action,
            #selector(KeyameleonApplicationDelegate.toggleMenuBarPanel(_:))
        )
        XCTAssertTrue(delegate.menuBarStatusItem?.button?.target === delegate)
        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        XCTAssertEqual(panel.behavior, .transient)
        XCTAssertEqual(panel.panelWidth, 360)
        XCTAssertFalse(delegate.isMenuBarPanelShown)

        let checksAfterLaunch = permission.checkCount
        panel.show(from: anchor.positioningView)

        XCTAssertTrue(delegate.isMenuBarPanelShown)
        XCTAssertGreaterThan(permission.checkCount, checksAfterLaunch)
        XCTAssertEqual(panel.panelWidth, 360)

        delegate.closeMenuBarPanel()
        XCTAssertFalse(delegate.isMenuBarPanelShown)

        panel.toggle(from: anchor.positioningView)
        XCTAssertFalse(delegate.isMenuBarPanelShown)
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
private final class MenuBarPanelTestAnchorWindow {
    private let window: NSWindow
    let positioningView: NSView

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 24),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.orderFrontRegardless()
        self.window = window
        self.positioningView = window.contentView!
    }

    func close() {
        window.close()
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
    private(set) var checkCount = 0

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        checkCount += 1
        return state
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
