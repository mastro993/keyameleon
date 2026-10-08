import AppKit
import SwiftUI

extension ApplicationDelegate {
    var menuBarStatusItem: NSStatusItem? {
        statusItem
    }

    func closeMenuBarPanel() {
        menuBarPanelController?.close()
    }

    /// Shows the status item once Guided setup is complete. Safe to call again.
    func startMenuBarApp() {
        guard statusItem == nil else {
            return
        }

        statusItem = makeStatusItem()
        menuBarPanelController = makeMenuBarPanelController()
        refreshMenuBarPresentation()
    }

    func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            return item
        }

        button.imagePosition = .imageOnly
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(AppIdentity.current.name)
        applyMenuBarIcon(to: button)
        return item
    }

    func makeMenuBarPanelController() -> MenuBarPanelController {
        let controller = MenuBarPanelController(
            setupModel: setupModel,
            switching: activityTriggeredSwitching,
            generalSettingsModel: generalSettingsModel,
            actions: makeMenuBarPanelActions()
        )
        statusItem?.menu = controller.menu
        return controller
    }

    func makeMenuBarPanelActions() -> MenuBarPanelActions {
        MenuBarPanelActions(
            openSettings: { [weak self] in self?.openSettings(nil) },
            checkForUpdates: { [weak self] in self?.checkForUpdates(nil) },
            quit: { [weak self] in self?.quitKeyameleon(nil) }
        )
    }

    func refreshMenuBarPresentation() {
        guard let button = statusItem?.button else {
            return
        }

        applyMenuBarIcon(to: button)
        menuBarPanelController?.refresh()
    }

    func observePresentationChanges() {
        withObservationTracking {
            _ = activityTriggeredSwitching.outcome
            _ = setupModel.physicalKeyboards
            _ = setupModel.eligibleInputSources
            _ = setupModel.persistenceError
            _ = activityTriggeredSwitching.persistenceError
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
    func quitKeyameleon(_ sender: Any?) {
        closeMenuBarPanel()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.terminate(sender)
    }

    func applyMenuBarIcon(to button: NSStatusBarButton) {
        let outcome = activityTriggeredSwitching.outcome
        let hasItemConditionsNeedingAction = !setupModel.physicalKeyboardActionConditions.isEmpty
            || outcome.mismatch != nil
        let mark = MenuBarIconMark.resolve(
            switchingStatus: outcome.switchingStatus,
            hasItemConditionsNeedingAction: hasItemConditionsNeedingAction
        )
        // One mark for every state; tooltip and accessibility text carry status.
        let image = statusImage(for: mark)
        if button.image !== image {
            button.image = image
        }

        let toolTip = menuBarIconAccessibilityDescription(for: mark)
        if button.toolTip != toolTip {
            button.toolTip = toolTip
        }

        button.setAccessibilityLabel(AppIdentity.current.name)
    }

    /// One status image per state, loaded once. `menu_icon.pdf` is read on the first request only.
    private func statusImage(for mark: MenuBarIconMark) -> NSImage? {
        if let menuBarStatusImage {
            return menuBarStatusImage
        }

        if let url = Bundle.main.url(forResource: "menu_icon", withExtension: "pdf"),
           let customImage = NSImage(contentsOf: url) {
            customImage.size = NSSize(width: 18, height: 18)
            customImage.accessibilityDescription = AppIdentity.current.name
            customImage.isTemplate = true
            menuBarStatusImage = customImage
            return customImage
        }

        let symbolName = systemSymbolName(for: mark)
        if let fallbackImage = menuBarFallbackImages[symbolName] {
            return fallbackImage
        }

        let fallbackImage =
            NSImage(systemSymbolName: symbolName, accessibilityDescription: AppIdentity.current.name)
            ?? NSImage(
                systemSymbolName: systemSymbolName(for: .ready),
                accessibilityDescription: AppIdentity.current.name
            )
        fallbackImage?.isTemplate = true
        if let fallbackImage {
            menuBarFallbackImages[symbolName] = fallbackImage
        }

        return fallbackImage
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
            AppIdentity.current.name
        case .permissionRequired:
            "\(AppIdentity.current.name) — Permission Required"
        case .temporarilyUnavailable:
            "\(AppIdentity.current.name) — Temporarily Unavailable"
        case .paused:
            "\(AppIdentity.current.name) — Paused"
        case .warning:
            "\(AppIdentity.current.name) — Action needed"
        }
    }
}
