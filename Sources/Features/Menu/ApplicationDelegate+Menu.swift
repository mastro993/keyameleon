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
