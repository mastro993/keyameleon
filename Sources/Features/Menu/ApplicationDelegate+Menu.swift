import AppKit
import SwiftUI

extension ApplicationDelegate {
    var menuBarStatusItem: NSStatusItem? {
        statusItem
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
        applyMenuBarIcon(to: button)
        return item
    }

    func makeMenuBarPanelController() -> MenuBarPanelController {
        let controller = MenuBarPanelController(
            setupModel: setupModel,
            switching: activityTriggeredSwitching,
            actions: makeMenuBarPanelActions()
        )
        statusItem?.menu = controller.menu
        return controller
    }

    func makeMenuBarPanelActions() -> MenuBarPanelActions {
        MenuBarPanelActions(
            openAbout: { [weak self] in self?.openAbout(nil) },
            continueSetup: { [weak self] in self?.continueSetup(nil) },
            openSettings: { [weak self] in self?.openSettings(nil) },
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
            _ = setupModel.isSetupComplete
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
            || !setupModel.isSetupComplete
            || outcome.mismatch != nil
        let mark = MenuBarIconMark.resolve(
            switchingStatus: outcome.switchingStatus,
            hasItemConditionsNeedingAction: hasItemConditionsNeedingAction
        )
        // Image accessibilityDescription must stay "Keyameleon" — XCUITest matches that id.
        // One mark for every state; tooltip and accessibility text carry status.
        let image = statusImage(for: mark)
        if button.image !== image {
            button.image = image
        }

        let toolTip = menuBarIconAccessibilityDescription(for: mark)
        if button.toolTip != toolTip {
            button.toolTip = toolTip
        }

        button.setAccessibilityLabel("Keyameleon")
    }

    /// One status image per state, loaded once. `menu_icon.pdf` is read on the first request only.
    private func statusImage(for mark: MenuBarIconMark) -> NSImage? {
        if let menuBarStatusImage {
            return menuBarStatusImage
        }

        if let url = Bundle.main.url(forResource: "menu_icon", withExtension: "pdf"),
           let customImage = NSImage(contentsOf: url) {
            customImage.size = NSSize(width: 18, height: 18)
            customImage.accessibilityDescription = "Keyameleon"
            customImage.isTemplate = true
            menuBarStatusImage = customImage
            return customImage
        }

        let symbolName = systemSymbolName(for: mark)
        if let fallbackImage = menuBarFallbackImages[symbolName] {
            return fallbackImage
        }

        let fallbackImage =
            NSImage(systemSymbolName: symbolName, accessibilityDescription: "Keyameleon")
            ?? NSImage(
                systemSymbolName: systemSymbolName(for: .ready),
                accessibilityDescription: "Keyameleon"
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
