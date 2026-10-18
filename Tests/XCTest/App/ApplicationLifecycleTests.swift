import AppKit
import SwiftUI
import XCTest
@testable import Keyameleon

final class ApplicationLifecycleTests: XCTestCase {
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
    func testClosingGuidedSetupBeforeCompletionTerminatesApplication() {
        let delegate = makeApplicationTestDelegate(
            setupStore: ApplicationTestSetupDecisionStore(hasCompletedGuidedSetup: false)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertTrue(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testCompletingGuidedSetupPresentsSettingsAndKeepsTheApplicationRunning() throws {
        let setupStore = ApplicationTestSetupDecisionStore(
            hasCompletedGuidedSetup: false,
            guidedSetupStep: .permission
        )
        let delegate = makeApplicationTestDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            setupStore: setupStore
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(delegate.setupModel.guidedSetupStep, .assignments)
        XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
        XCTAssertNil(delegate.settingsWindowController)

        delegate.setupModel.continueToReady()
        delegate.setupModel.completeSetup(destination: .settings)

        let settingsWindow = try XCTUnwrap(delegate.settingsWindowController?.window)
        XCTAssertTrue(settingsWindow.isVisible)
        XCTAssertFalse(delegate.windowController?.window?.isVisible ?? true)
        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testFinishingGuidedSetupLeavesOnlyMenuBarRunning() {
        let delegate = makeApplicationTestDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            setupStore: ApplicationTestSetupDecisionStore(
                hasCompletedGuidedSetup: false, guidedSetupStep: .ready
            )
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
        XCTAssertNil(delegate.menuBarStatusItem)
        XCTAssertNil(delegate.menuBarPanelController)
        XCTAssertFalse(delegate.activityTriggeredSwitching.appliesKeyboardAssignments)
        XCTAssertEqual(delegate.activationPolicy, .regular)

        delegate.setupModel.completeSetup(destination: .menuBar)
        XCTAssertEqual(delegate.activationPolicy, .accessory)
        XCTAssertFalse(delegate.windowController?.window?.isVisible ?? true)
        XCTAssertNil(delegate.settingsWindowController)
        XCTAssertNotNil(delegate.menuBarStatusItem)
        XCTAssertNotNil(delegate.menuBarPanelController)
        XCTAssertTrue(delegate.activityTriggeredSwitching.appliesKeyboardAssignments)
        XCTAssertTrue(delegate.setupModel.isSetupComplete)
    }

    @MainActor
    func testReopenShowsClosedGuidedSetupAtSavedStepWithoutMenuBar() {
        for (step, permission) in [
            (GuidedSetupStep.permission, ListenPermissionState.denied),
            (.assignments, .granted),
            (.ready, .granted)
        ] {
            let setupStore = ApplicationTestSetupDecisionStore(
                hasStartedGuidedSetup: true,
                hasCompletedGuidedSetup: false,
                guidedSetupStep: step
            )
            let delegate = makeApplicationTestDelegate(
                permissionProvider: ApplicationTestListenPermissionProvider(state: permission),
                setupStore: setupStore
            )
            delegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
            defer {
                stopApplicationTestSurface(delegate)
                delegate.windowController?.close()
            }
            XCTAssertEqual(delegate.setupModel.guidedSetupStep, step)
            XCTAssertNil(delegate.menuBarStatusItem)
            delegate.windowController?.close()
            XCTAssertFalse(delegate.windowController?.window?.isVisible ?? true)

            XCTAssertFalse(
                delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
            )
            XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
            XCTAssertNil(delegate.menuBarStatusItem)
            XCTAssertEqual(delegate.setupModel.guidedSetupStep, step)
            XCTAssertFalse(delegate.setupModel.isSetupComplete)
        }
    }

    @MainActor
    func testRelaunchAfterPermissionGrantOpensKeyboardCheck() throws {
        let setupStore = ApplicationTestSetupDecisionStore(
            hasStartedGuidedSetup: true,
            hasCompletedGuidedSetup: false,
            guidedSetupStep: .permission
        )
        let delegate = makeApplicationTestDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .granted),
            setupStore: setupStore
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(delegate.setupModel.guidedSetupStep, .assignments)
        XCTAssertFalse(delegate.setupModel.isSetupComplete)
        XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
        XCTAssertNil(delegate.settingsWindowController)
    }

    @MainActor
    func testReopenDoesNotReactivateOrOpenTheRunningApplication() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertFalse(
            delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        )
        XCTAssertNil(delegate.windowController)
    }
}
