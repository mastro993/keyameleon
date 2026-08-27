import AppKit
import XCTest
@testable import Keyameleon

final class KeyameleonApplicationTests: XCTestCase {
    private var keyameleonBundle: Bundle? {
        Bundle(identifier: "dev.fedemas.keyameleon.development")
            ?? Bundle(identifier: "dev.fedemas.keyameleon")
    }

    @MainActor
    func testStatusItemOpensTransient280PointPanelAndCloses() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = makeApplicationTestDelegate(permissionProvider: permission)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        let anchor = MenuBarPanelTestAnchorWindow()
        defer {
            stopApplicationTestSurface(delegate)
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
        XCTAssertEqual(panel.panelWidth, 280)
        XCTAssertFalse(delegate.isMenuBarPanelShown)

        let checksAfterLaunch = permission.checkCount
        panel.show(from: anchor.positioningView)

        XCTAssertTrue(delegate.isMenuBarPanelShown)
        XCTAssertGreaterThan(permission.checkCount, checksAfterLaunch)
        XCTAssertEqual(panel.panelWidth, 280)

        delegate.closeMenuBarPanel()
        XCTAssertFalse(delegate.isMenuBarPanelShown)

        panel.toggle(from: anchor.positioningView)
        XCTAssertFalse(delegate.isMenuBarPanelShown)
    }

    @MainActor
    func testCheckForUpdatesClosesTheMenuBarPanel() throws {
        let delegate = makeApplicationTestDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        let anchor = MenuBarPanelTestAnchorWindow()
        defer {
            stopApplicationTestSurface(delegate)
            anchor.close()
        }

        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        panel.show(from: anchor.positioningView)
        XCTAssertTrue(delegate.isMenuBarPanelShown)

        delegate.checkForUpdates(nil)
        XCTAssertFalse(delegate.isMenuBarPanelShown)
    }

    @MainActor
    func testAboutActionShowsAnIndependentNonResizableWindow() throws {
        let delegate = makeApplicationTestDelegate(startsApplicationSurfaceOnLaunch: false)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        delegate.openSettings(nil)
        delegate.openAbout(nil)

        let settingsWindow = try XCTUnwrap(delegate.settingsWindowController?.window)
        let aboutWindow = try XCTUnwrap(delegate.aboutWindowController?.window)

        XCTAssertTrue(settingsWindow.isVisible)
        XCTAssertTrue(aboutWindow.isVisible)
        XCTAssertFalse(settingsWindow === aboutWindow)
        XCTAssertEqual(aboutWindow.identifier?.rawValue, "keyameleon.about-window")
        XCTAssertFalse(aboutWindow.styleMask.contains(.resizable))
        XCTAssertEqual(aboutWindow.contentLayoutRect.size, NSSize(width: 380, height: 320))
    }

    @MainActor
    func testDismissingTheMenuBarPanelDoesNotMutateProductState() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = makeApplicationTestDelegate(permissionProvider: permission)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        let anchor = MenuBarPanelTestAnchorWindow()
        defer {
            stopApplicationTestSurface(delegate)
            anchor.close()
        }

        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        panel.show(from: anchor.positioningView)
        XCTAssertTrue(delegate.isMenuBarPanelShown)

        let statusAfterShow = delegate.activityTriggeredSwitching.outcome.switchingStatus
        let pausedAfterShow = delegate.setupModel.isActivityTriggeredSwitchingPaused
        let keyboardsAfterShow = delegate.setupModel.physicalKeyboards
        let checksAfterShow = permission.checkCount

        delegate.closeMenuBarPanel()
        XCTAssertFalse(delegate.isMenuBarPanelShown)
        XCTAssertEqual(
            delegate.activityTriggeredSwitching.outcome.switchingStatus,
            statusAfterShow
        )
        XCTAssertEqual(
            delegate.setupModel.isActivityTriggeredSwitchingPaused,
            pausedAfterShow
        )
        XCTAssertEqual(delegate.setupModel.physicalKeyboards, keyboardsAfterShow)
        XCTAssertEqual(permission.checkCount, checksAfterShow)
    }

    @MainActor
    func testMenuBarIconPresentationMapsEveryStatusMark() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }
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
        let delegate = makeApplicationTestDelegate(
            updateChecker: updates,
            startsUpdaterOnLaunch: true
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(updates.startCallCount, 1)
    }

    @MainActor
    func testApplicationCanSkipUpdateCheckerOnLaunch() {
        let updates = ApplicationTestUpdateChecker()
        let delegate = makeApplicationTestDelegate(
            updateChecker: updates,
            startsUpdaterOnLaunch: false
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(updates.startCallCount, 0)
    }

    @MainActor
    func testHostedLaunchSkipsApplicationSurface() {
        let discoverer = ApplicationTestPhysicalKeyboardDiscoverer()
        let delegate = makeApplicationTestDelegate(
            physicalKeyboardDiscoverer: discoverer,
            startsApplicationSurfaceOnLaunch: false
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertNil(delegate.menuBarStatusItem)
        XCTAssertNil(delegate.menuBarPanelController)
        XCTAssertEqual(discoverer.startCount, 0)
    }

    @MainActor
    func testClosingLastWindowDoesNotTerminateApplication() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testReopenDoesNotReactivateOrOpenTheRunningApplication() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }

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
