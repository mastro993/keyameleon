import AppKit
import SwiftUI

extension KeyameleonApplicationDelegate {
    var menuBarStatusItem: NSStatusItem? {
        statusItem
    }

    var isMenuBarPanelShown: Bool {
        menuBarPanelController?.isShown ?? false
    }

    @objc
    func toggleMenuBarPanel(_ sender: Any?) {
        guard let button = statusItem?.button else {
            return
        }

        if menuBarPanelController == nil {
            menuBarPanelController = makeMenuBarPanelController()
        }
        menuBarPanelController?.toggle(from: button)
    }

    func closeMenuBarPanel() {
        menuBarPanelController?.close()
    }

    func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            return item
        }

        button.imagePosition = .imageOnly
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel("Keyameleon")
        button.target = self
        button.action = #selector(toggleMenuBarPanel(_:))
        applyMenuBarIcon(to: button)
        return item
    }

    func makeMenuBarPanelController() -> KeyameleonMenuBarPanelController {
        KeyameleonMenuBarPanelController(
            rootView: KeyameleonMenuBarPanelView(
                setupModel: setupModel,
                switching: activityTriggeredSwitching,
                actions: MenuBarPanelActions(
                    openAbout: { [weak self] in
                        self?.openAbout(nil)
                    },
                    openSettings: { [weak self] in
                        self?.openSettings(nil)
                    },
                    quit: { [weak self] in
                        self?.quitKeyameleon(nil)
                    },
                    closePanel: { [weak self] in
                        self?.closeMenuBarPanel()
                    }
                )
            ),
            refresh: { [weak self] in
                self?.activityTriggeredSwitching.checkAgain()
                self?.refreshMenuBarPresentation()
            }
        )
    }

    func refreshMenuBarPresentation() {
        guard let button = statusItem?.button else {
            return
        }

        applyMenuBarIcon(to: button)
    }

    func observePresentationChanges() {
        withObservationTracking {
            _ = activityTriggeredSwitching.outcome
            _ = setupModel.physicalKeyboards
            _ = setupModel.isSetupComplete
            _ = setupModel.physicalKeyboardActionConditions
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.refreshMenuBarPresentation()
                self.observePresentationChanges()
            }
        }
    }

    @objc
    func openKeyameleon(_ sender: Any?) {
        setupModel.beginGuidedSetup()
        closeMenuBarPanel()
        NSApp.activate(ignoringOtherApps: true)

        if windowController == nil {
            windowController = KeyameleonWindowController(
                model: setupModel,
                switching: activityTriggeredSwitching
            )
        }

        windowController?.showWindow(sender)
        windowController?.window?.orderFrontRegardless()
    }

    func presentSettingsAfterGuidedSetup() {
        openSettings(nil)
        windowController?.close()
    }

    @objc
    func reviewDiagnostics(_ sender: Any?) {
        closeMenuBarPanel()
        uncleanExitStateStore.dismissUncleanExitNotice()
        generalSettingsModel.refresh()
        if diagnosticReviewWindowController == nil {
            diagnosticReviewWindowController = KeyameleonDiagnosticWindowController(
                model: generalSettingsModel
            )
        }

        diagnosticReviewWindowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        refreshMenuBarPresentation()
    }

    @objc
    func dismissDiagnosticsNotice(_ sender: Any?) {
        uncleanExitStateStore.dismissUncleanExitNotice()
        refreshMenuBarPresentation()
    }

    @objc
    func continueSetup(_ sender: Any?) {
        openKeyameleon(sender)
    }

    @objc
    func openSettings(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()

        if settingsWindowController == nil {
            settingsWindowController = KeyameleonSettingsWindowController(
                model: generalSettingsModel,
                setupModel: setupModel
            )
        }

        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func openAbout(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()

        if aboutWindowController == nil {
            aboutWindowController = KeyameleonAboutWindowController(
                model: generalSettingsModel
            )
        }

        aboutWindowController?.showWindow(sender)
        aboutWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func checkForUpdates(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.checkForUpdates()
        refreshMenuBarPresentation()
    }

    @objc
    func quitKeyameleon(_ sender: Any?) {
        closeMenuBarPanel()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.terminate(sender)
    }

    func applyMenuBarIcon(to button: NSStatusBarButton) {
        let outcome = activityTriggeredSwitching.outcome
        let hasItemConditionsNeedingAction = !setupModel.physicalKeyboardActionConditions.isEmpty
            || !setupModel.isSetupComplete
            || outcome.mismatch != nil
        let mark = MenuBarIconMark.resolve(
            switchingStatus: outcome.switchingStatus,
            hasItemConditionsNeedingAction: hasItemConditionsNeedingAction
        )
        // Image accessibilityDescription must stay "Keyameleon" — XCUITest matches that id.
        // Distinct SF Symbol shape + tooltip carry status without relying on color alone.
        let image =
            NSImage(
                systemSymbolName: systemSymbolName(for: mark),
                accessibilityDescription: "Keyameleon"
            )
            ?? NSImage(
                systemSymbolName: systemSymbolName(for: .ready),
                accessibilityDescription: "Keyameleon"
            )
        image?.isTemplate = true
        button.image = image
        button.toolTip = menuBarIconAccessibilityDescription(for: mark)
        button.setAccessibilityLabel("Keyameleon")
    }

    func systemSymbolName(for mark: MenuBarIconMark) -> String {
        switch mark {
        case .ready:
            "keyboard"
        case .permissionRequired:
            "keyboard.badge.ellipsis"
        case .temporarilyUnavailable:
            "moon.zzz"
        case .paused:
            "pause.circle"
        case .warning:
            "exclamationmark.triangle"
        }
    }

    func menuBarIconAccessibilityDescription(for mark: MenuBarIconMark) -> String {
        switch mark {
        case .ready:
            "Keyameleon"
        case .permissionRequired:
            "Keyameleon — Permission Required"
        case .temporarilyUnavailable:
            "Keyameleon — Temporarily Unavailable"
        case .paused:
            "Keyameleon — Paused"
        case .warning:
            "Keyameleon — Action needed"
        }
    }
}
