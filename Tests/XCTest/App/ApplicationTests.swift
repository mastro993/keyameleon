import AppKit
import SwiftUI
import XCTest
@testable import Keyameleon

final class ApplicationTests: XCTestCase {
    private var keyameleonBundle: Bundle? {
        Bundle(identifier: "dev.fedemas.keyameleon.development")
            ?? Bundle(identifier: "dev.fedemas.keyameleon")
    }

    @MainActor
    func testStatusItemUsesNativeMenuAndOnlyKeyboardsHaveAView() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = makeApplicationTestDelegate(permissionProvider: permission)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let controller = try XCTUnwrap(delegate.menuBarPanelController)
        let menu = try XCTUnwrap(delegate.menuBarStatusItem?.menu)
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let headingTitle = "\(AppIdentity.current.name) v\(version.isEmpty ? "—" : version)"
        let heading = try XCTUnwrap(menu.items.first)
        XCTAssertTrue(menu === controller.menu)
        XCTAssertEqual(heading.identifier?.rawValue, "menu-bar-heading")
        XCTAssertEqual(heading.title, headingTitle)
        XCTAssertNil(menu.items.first { $0.identifier?.rawValue == "menu-bar-version" })
        XCTAssertEqual(menu.items.last?.title, "Quit \(AppIdentity.current.name)")
        XCTAssertNil(delegate.menuBarStatusItem?.button?.action)
        XCTAssertEqual(menu.items.filter { $0.view != nil }.count, 1)
        XCTAssertNotNil(menu.items.first { $0.title == "Keyboards" })
        XCTAssertNil(menu.items.first { $0.identifier?.rawValue == "menu-bar-keyboards-heading" })
        XCTAssertNil(menu.items.first { $0.title == "About Keyameleon" })
        XCTAssertNotNil(menu.items.first { $0.title == "Quit \(AppIdentity.current.name)" })
        XCTAssertEqual(menu.items.first { $0.title == "Pause Switching" }?.keyEquivalent, "p")
        XCTAssertEqual(menu.items.first { $0.title == "Settings" }?.keyEquivalent, ",")
        XCTAssertEqual(menu.items.first { $0.title == "Quit \(AppIdentity.current.name)" }?.keyEquivalent, "q")
        XCTAssertTrue(menu.items.filter { !$0.keyEquivalent.isEmpty }.allSatisfy {
            $0.keyEquivalentModifierMask == [.command]
        })

        let checksAfterLaunch = permission.checkCount
        controller.menuNeedsUpdate(menu)
        XCTAssertGreaterThan(permission.checkCount, checksAfterLaunch)
        XCTAssertTrue(menu.items.first === heading)
        XCTAssertEqual(heading.title, headingTitle)
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Pause Switching" }))
        XCTAssertTrue(delegate.setupModel.isActivityTriggeredSwitchingPaused)
        controller.refresh()
        XCTAssertTrue(menu.items.first === heading)
        XCTAssertEqual(heading.title, "\(headingTitle) (Paused)")
        XCTAssertNotNil(menu.items.first { $0.title == "Resume Switching" })
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Resume Switching" }))
        XCTAssertFalse(delegate.setupModel.isActivityTriggeredSwitchingPaused)
        controller.refresh()
        XCTAssertTrue(menu.items.first === heading)
        XCTAssertEqual(heading.title, headingTitle)
        XCTAssertEqual(menu.items.last?.title, "Quit \(AppIdentity.current.name)")
    }

    @MainActor
    func testMenuNoticesReplaceKeyboardsAndRestoreTheList() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = makeApplicationTestDelegate(
            permissionProvider: permission,
            setupStore: ApplicationTestSetupDecisionStore(
                hasStartedGuidedSetup: true,
                hasCompletedGuidedSetup: false,
                guidedSetupStep: .ready
            )
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        let menu = panel.menu
        let noticeItem = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "menu-bar-notice" })
        let noticeHost = try XCTUnwrap(noticeItem.view as? NSHostingView<MenuBarPanelNoticeView>)
        let settings = try XCTUnwrap(menu.items.first { $0.title == "Settings" })
        XCTAssertEqual(noticeHost.rootView.notice.title, "Finish Guided Setup")
        XCTAssertEqual(noticeHost.rootView.notice.action.id, .continueSetup)
        XCTAssertTrue(noticeHost.rootView.notice.action.isEnabled)
        XCTAssertGreaterThan(noticeHost.frame.height, 0)
        XCTAssertEqual(noticeHost.frame.width, Theme.Menu.width)
        XCTAssertNil(menu.items.first { $0.title == "Keyboards" })
        XCTAssertEqual(menu.items.filter { $0.view != nil }.count, 1)

        delegate.windowController?.close()
        noticeHost.rootView.perform(noticeHost.rootView.notice.action.id)
        XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
        panel.refresh()
        XCTAssertTrue(settings === menu.items.first { $0.title == "Settings" })

        delegate.setupModel.completeSetup(destination: .menuBar)
        panel.refresh()
        XCTAssertNil(menu.items.first { $0.identifier?.rawValue == "menu-bar-notice" })
        let keyboards = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "menu-bar-keyboards" })
        let hosted = try XCTUnwrap(keyboards.view)
        let keyboardMenuWidth = menu.size.width
        panel.refresh()
        XCTAssertTrue(keyboards === menu.items.first { $0.identifier?.rawValue == "menu-bar-keyboards" })
        XCTAssertTrue(hosted === keyboards.view)

        permission.state = .denied
        panel.menuNeedsUpdate(menu)
        let permissionItem = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "menu-bar-notice" })
        let permissionHost = try XCTUnwrap(permissionItem.view as? NSHostingView<MenuBarPanelNoticeView>)
        XCTAssertEqual(permissionHost.rootView.notice.title, "Input Monitoring required")
        XCTAssertTrue([MenuBarPanelActionID.openSystemSettings, .requestPermission].contains(
            permissionHost.rootView.notice.action.id
        ))
        XCTAssertNil(menu.items.first { $0.title == "Keyboards" })
        XCTAssertEqual(menu.size.width, keyboardMenuWidth)
        XCTAssertTrue(settings === menu.items.first { $0.title == "Settings" })

        permission.state = .granted
        panel.menuNeedsUpdate(menu)
        XCTAssertNil(menu.items.first { $0.identifier?.rawValue == "menu-bar-notice" })
        XCTAssertNotNil(menu.items.first { $0.identifier?.rawValue == "menu-bar-keyboards" })
        XCTAssertEqual(menu.size.width, keyboardMenuWidth)
        delegate.activityTriggeredSwitching.pause()
        panel.refresh()
        XCTAssertNotNil(menu.items.first {
            $0.representedObject as? String == MenuBarPanelActionID.resume.rawValue
        })
        XCTAssertEqual(menu.items.filter { $0.view != nil }.count, 1)
    }

    @MainActor
    func testPermissionNoticeButtonOpensSystemSettings() throws {
        let opener = ApplicationTestSystemSettingsOpener()
        let delegate = makeApplicationTestDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .denied),
            systemSettingsOpener: opener
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        let item = try XCTUnwrap(panel.menu.items.first { $0.identifier?.rawValue == "menu-bar-notice" })
        let host = try XCTUnwrap(item.view as? NSHostingView<MenuBarPanelNoticeView>)
        host.layoutSubtreeIfNeeded()
        let button = try XCTUnwrap(noticeButton(in: host))
        XCTAssertEqual(button.title, "Open System Settings")
        button.performClick(nil)
        XCTAssertEqual(opener.openCount, 1)

        let notice = host.rootView.notice
        var replacementCalls = 0
        host.rootView = MenuBarPanelNoticeView(
            notice: MenuBarPanelNotice(
                title: notice.title,
                detail: notice.detail,
                action: .init(id: notice.action.id, title: notice.action.title, isEnabled: false),
                tone: notice.tone
            ),
            perform: { _ in replacementCalls += 1 }
        )
        host.layoutSubtreeIfNeeded()
        let disabledButton = try XCTUnwrap(noticeButton(in: host))
        disabledButton.performClick(nil)
        XCTAssertEqual(opener.openCount, 1)
        XCTAssertEqual(replacementCalls, 0)

        host.rootView = MenuBarPanelNoticeView(
            notice: notice,
            perform: { _ in replacementCalls += 1 }
        )
        host.layoutSubtreeIfNeeded()
        let refreshedButton = try XCTUnwrap(noticeButton(in: host))
        refreshedButton.performClick(nil)
        XCTAssertEqual(opener.openCount, 1)
        XCTAssertEqual(replacementCalls, 1)
    }

    @MainActor
    private func noticeButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton {
            return button
        }
        for subview in view.subviews {
            if let button = noticeButton(in: subview) {
                return button
            }
        }
        return nil
    }

    @MainActor
    func testCheckForUpdatesKeepsNativeMenuAttached() throws {
        let updateChecker = ApplicationTestUpdateChecker()
        let delegate = makeApplicationTestDelegate(updateChecker: updateChecker)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let controller = try XCTUnwrap(delegate.menuBarPanelController)
        let menu = try XCTUnwrap(delegate.menuBarStatusItem?.menu)
        let settingsIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == "Settings" })
        let updateIndex = settingsIndex + 1
        let updateItem = try XCTUnwrap(menu.item(at: updateIndex))
        XCTAssertEqual(updateItem.title, "Check for Updates…")
        XCTAssertLessThan(updateIndex, try XCTUnwrap(menu.items.firstIndex { $0.title == "Quit \(AppIdentity.current.name)" }))
        XCTAssertEqual(updateItem.representedObject as? String, MenuBarPanelActionID.checkForUpdates.rawValue)
        XCTAssertNil(updateItem.view)
        XCTAssertNil(updateItem.toolTip)
        XCTAssertEqual(updateItem.keyEquivalent, "")
        XCTAssertEqual(updateItem.keyEquivalentModifierMask, [])
        XCTAssertFalse(updateItem.isEnabled)
        XCTAssertEqual(updateChecker.checkCallCount, 0)

        updateChecker.canCheckForUpdates = true
        controller.menuNeedsUpdate(menu)
        XCTAssertTrue(menu.item(at: updateIndex) === updateItem)
        XCTAssertTrue(updateItem.isEnabled)
        XCTAssertEqual(updateChecker.checkCallCount, 0)

        menu.performActionForItem(at: updateIndex)
        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertFalse(updateItem.isEnabled)
        XCTAssertTrue(menu.item(at: updateIndex) === updateItem)
        XCTAssertTrue(delegate.menuBarStatusItem?.menu === menu)

        updateChecker.canCheckForUpdates = true
        controller.menuNeedsUpdate(menu)
        XCTAssertTrue(updateItem.isEnabled)
        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertTrue(menu.item(at: updateIndex) === updateItem)
        XCTAssertTrue(delegate.menuBarStatusItem?.menu === menu)
    }

    @MainActor
    func testSettingsWindowPreservesAboutSelectionAcrossReopen() throws {
        let delegate = makeApplicationTestDelegate(startsApplicationSurfaceOnLaunch: false)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(delegate.settingsSelection.section, .general)

        delegate.openSettings(nil)
        let settingsWindow = try XCTUnwrap(delegate.settingsWindowController?.window)
        XCTAssertEqual(settingsWindow.identifier?.rawValue, "keyameleon.settings-window")
        XCTAssertEqual(delegate.settingsSelection.section, .general)
        XCTAssertEqual(delegate.settingsWindowController?.selectedSection, .general)
        XCTAssertNil(settingsWindow.toolbar)
        XCTAssertTrue(settingsWindow.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(settingsWindow.titleVisibility, .hidden)
        XCTAssertTrue(settingsWindow.titlebarAppearsTransparent)
        XCTAssertEqual(
            settingsWindow.contentMinSize,
            NSSize(
                width: Theme.Metrics.settingsWindowMinimumWidth,
                height: Theme.Metrics.settingsWindowMinimumHeight
            )
        )
        XCTAssertTrue(settingsWindow.contentView is NSHostingView<SettingsView>)

        delegate.settingsSelection.section = .about
        XCTAssertEqual(delegate.settingsWindowController?.selectedSection, .about)
        settingsWindow.close()
        delegate.openSettings(nil)
        XCTAssertEqual(delegate.settingsSelection.section, .about)
        XCTAssertEqual(delegate.settingsWindowController?.selectedSection, .about)
        XCTAssertTrue(delegate.settingsWindowController?.window === settingsWindow)
    }

    @MainActor
    func testCancelingNativeMenuDoesNotMutateProductState() throws {
        let permission = ApplicationTestListenPermissionProvider(state: .granted)
        let delegate = makeApplicationTestDelegate(permissionProvider: permission)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let controller = try XCTUnwrap(delegate.menuBarPanelController)
        controller.menuNeedsUpdate(controller.menu)
        let status = delegate.activityTriggeredSwitching.outcome.switchingStatus
        let paused = delegate.setupModel.isActivityTriggeredSwitchingPaused
        let keyboards = delegate.setupModel.physicalKeyboards
        let checks = permission.checkCount
        delegate.closeMenuBarPanel()
        XCTAssertEqual(delegate.activityTriggeredSwitching.outcome.switchingStatus, status)
        XCTAssertEqual(delegate.setupModel.isActivityTriggeredSwitchingPaused, paused)
        XCTAssertEqual(delegate.setupModel.physicalKeyboards, keyboards)
        XCTAssertEqual(permission.checkCount, checks)
    }

    @MainActor
    func testMenuBarIconFallbackMapsEveryStatusMark() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }
        let expected: [(MenuBarIconMark, String, String)] = [
            (.ready, "keyboard", AppIdentity.current.name),
            (.permissionRequired, "keyboard.badge.ellipsis", "\(AppIdentity.current.name) — Permission Required"),
            (.temporarilyUnavailable, "moon.zzz", "\(AppIdentity.current.name) — Temporarily Unavailable"),
            (.paused, "pause.circle", "\(AppIdentity.current.name) — Paused"),
            (.warning, "exclamationmark.triangle", "\(AppIdentity.current.name) — Action needed")
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
    func testMenuBarIconUsesBundledPDFAtTemplateSize() throws {
        let delegate = makeApplicationTestDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let image = try XCTUnwrap(delegate.menuBarStatusItem?.button?.image)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, AppIdentity.current.name)
        XCTAssertNotNil(keyameleonBundle?.url(forResource: "menu_icon", withExtension: "pdf"))
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
        delegate.setupModel.completeSetup(destination: .menuBar)
        XCTAssertFalse(delegate.windowController?.window?.isVisible ?? true)
        XCTAssertNil(delegate.settingsWindowController)
        XCTAssertNotNil(delegate.menuBarStatusItem)
        XCTAssertTrue(delegate.setupModel.isSetupComplete)
    }

    @MainActor
    func testMenuActionContinuesClosedGuidedSetupAtSavedStep() throws {
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
            delegate.windowController?.close()
            XCTAssertFalse(delegate.windowController?.window?.isVisible ?? true)

            let panel = try XCTUnwrap(delegate.menuBarPanelController)
            let item = try XCTUnwrap(panel.menu.items.first { $0.title == "Continue Guided Setup" })
            XCTAssertEqual(item.representedObject as? String, MenuBarPanelActionID.continueSetup.rawValue)
            panel.menu.performActionForItem(at: try XCTUnwrap(
                panel.menu.items.firstIndex { $0.title == "Continue Guided Setup" }
            ))
            XCTAssertTrue(delegate.windowController?.window?.isVisible ?? false)
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
            UpdatePolicy.feedURLString
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
        XCTAssertEqual(
            bundle?.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? Int,
            Int(UpdatePolicy.minimumCheckInterval)
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool, false)
    }
}
