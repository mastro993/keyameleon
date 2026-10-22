import AppKit
import SwiftUI
import XCTest
@testable import Keyameleon

final class ApplicationMenuTests: XCTestCase {
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
        let delegate = makeApplicationTestDelegate(permissionProvider: permission)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let panel = try XCTUnwrap(delegate.menuBarPanelController)
        let menu = panel.menu
        let settings = try XCTUnwrap(menu.items.first { $0.title == "Settings" })
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
        XCTAssertEqual(permissionHost.rootView.notice.title, "Input Monitoring is off")
        XCTAssertEqual(permissionHost.rootView.notice.action.id, .openSystemSettings)
        XCTAssertTrue(permissionHost.rootView.notice.action.isEnabled)
        XCTAssertGreaterThan(permissionHost.frame.height, 0)
        XCTAssertEqual(permissionHost.frame.width, Theme.Menu.width)
        XCTAssertNil(menu.items.first { $0.title == "Keyboards" })
        XCTAssertEqual(menu.items.filter { $0.view != nil }.count, 1)
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
        let opener = ApplicationTestInputMonitoringRecovery()
        let delegate = makeApplicationTestDelegate(
            permissionProvider: ApplicationTestListenPermissionProvider(state: .denied),
            inputMonitoringRecovery: opener
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

        let restart = try XCTUnwrap(panel.menu.items.first {
            $0.representedObject as? String == MenuBarPanelActionID.relaunch.rawValue
        })
        XCTAssertEqual(restart.title, "Restart \(AppIdentity.current.name)")
        panel.menu.performActionForItem(at: panel.menu.index(of: restart))
        XCTAssertEqual(opener.relaunchCount, 1)

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
        let toolbar = try XCTUnwrap(settingsWindow.toolbar)
        XCTAssertEqual(settingsWindow.toolbarStyle, .preference)
        XCTAssertEqual(toolbar.items.map(\.itemIdentifier.rawValue), ["general", "keyboards", "apps", "about"])
        XCTAssertEqual(toolbar.items.map(\.label), ["General", "Keyboards", "Apps", "About"])
        XCTAssertEqual(toolbar.selectedItemIdentifier?.rawValue, "general")
        XCTAssertEqual(settingsWindow.title, AppIdentity.current.name)
        XCTAssertFalse(settingsWindow.styleMask.contains(.resizable))
        XCTAssertEqual(
            settingsWindow.contentRect(forFrameRect: settingsWindow.frame).size,
            NSSize(
                width: Theme.Metrics.settingsWindowWidth,
                height: Theme.Metrics.settingsWindowHeight
            )
        )
        XCTAssertTrue(settingsWindow.contentView is NSHostingView<SettingsView>)

        let aboutItem = try XCTUnwrap(toolbar.items.last)
        NSApp.sendAction(try XCTUnwrap(aboutItem.action), to: aboutItem.target, from: aboutItem)
        XCTAssertEqual(delegate.settingsWindowController?.selectedSection, .about)
        XCTAssertEqual(toolbar.selectedItemIdentifier?.rawValue, "about")
        XCTAssertEqual(settingsWindow.title, AppIdentity.current.name)
        settingsWindow.close()
        delegate.openSettings(nil)
        XCTAssertEqual(delegate.settingsSelection.section, .about)
        XCTAssertEqual(delegate.settingsWindowController?.selectedSection, .about)
        XCTAssertEqual(toolbar.selectedItemIdentifier?.rawValue, "about")
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
}
