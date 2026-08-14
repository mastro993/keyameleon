import AppKit
import SwiftUI

/// Decides whether dismissing More should also close the menu-bar panel.
enum MenuBarOverflowMenuDismissal {
    /// Choosing an item already closes the panel. Clicking away must too —
    /// `NSMenu.popUp` eats the click that a transient popover would use.
    static func shouldClosePanelAfterMenuDismiss(didSelectItem: Bool) -> Bool {
        didSelectItem == false
    }
}

enum MenuBarFooterIconButton {
    @MainActor
    static func make(
        systemSymbolName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        target: AnyObject?,
        action: Selector
    ) -> NSButton {
        let button = NSButton(title: "", target: target, action: action)
        button.bezelStyle = .circular
        button.controlSize = .small
        button.isBordered = true
        button.setButtonType(.momentaryPushIn)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        let symbolSize = NSFont.systemFontSize(for: .small) + 1
        button.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: symbolSize,
            weight: .medium
        )
        button.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.setAccessibilityLabel(accessibilityLabel)
        button.setAccessibilityIdentifier(accessibilityIdentifier)
        return button
    }
}

/// Footer Settings icon. Same chrome as the overflow control.
@MainActor
struct MenuBarSettingsButton: NSViewRepresentable {
    var perform: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        MenuBarFooterIconButton.make(
            systemSymbolName: "gearshape",
            accessibilityLabel: "Open Keyameleon",
            accessibilityIdentifier: "menu-bar-open-keyameleon",
            target: context.coordinator,
            action: #selector(Coordinator.run)
        )
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.perform = perform
        if context.environment.isFocused {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var perform: (() -> Void)?

        @objc
        func run(_: NSButton) {
            perform?()
        }
    }
}

/// AppKit overflow control so XCUITest can open the footer menu inside the popover.
@MainActor
struct MenuBarOverflowButton: NSViewRepresentable {
    var actions: [MenuBarPanelContent.Action]
    var perform: (MenuBarPanelContent.Action) -> Void
    var closePanel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        MenuBarFooterIconButton.make(
            systemSymbolName: "ellipsis",
            accessibilityLabel: "More",
            accessibilityIdentifier: "menu-bar-panel-overflow",
            target: context.coordinator,
            action: #selector(Coordinator.showMenu(_:))
        )
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.actions = actions
        context.coordinator.perform = perform
        context.coordinator.closePanel = closePanel
        if context.environment.isFocused {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var actions: [MenuBarPanelContent.Action] = []
        var perform: ((MenuBarPanelContent.Action) -> Void)?
        var closePanel: (() -> Void)?
        private var didSelectItem = false

        @objc
        func showMenu(_ sender: NSButton) {
            didSelectItem = false
            let menu = makeMenu()
            let monitors = installDismissMonitors(for: menu)
            defer {
                for monitor in monitors {
                    NSEvent.removeMonitor(monitor)
                }
            }

            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)

            if MenuBarOverflowMenuDismissal.shouldClosePanelAfterMenuDismiss(
                didSelectItem: didSelectItem
            ) {
                closePanel?()
            }
        }

        @objc
        func runAction(_ sender: NSMenuItem) {
            didSelectItem = true
            guard
                let rawValue = sender.representedObject as? String,
                let actionID = MenuBarPanelActionID(rawValue: rawValue),
                let action = actions.first(where: { $0.id == actionID })
            else {
                return
            }

            perform?(action)
        }

        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for action in actions {
                if action.id == .checkForUpdates || action.id == .quit {
                    menu.addItem(.separator())
                }

                let item = NSMenuItem(
                    title: action.title,
                    action: #selector(runAction(_:)),
                    keyEquivalent: keyEquivalent(for: action.id)
                )
                item.keyEquivalentModifierMask = action.id == .settings || action.id == .quit
                    ? .command
                    : []
                item.target = self
                item.representedObject = action.id.rawValue
                item.isEnabled = action.isEnabled
                menu.addItem(item)
            }
            return menu
        }

        /// Clicks outside the menu window cancel tracking. Transient popovers
        /// otherwise swallow those clicks and leave both menus up.
        private func installDismissMonitors(for menu: NSMenu) -> [Any] {
            let handler: (NSEvent) -> NSEvent? = { event in
                if event.window?.level != .popUpMenu {
                    menu.cancelTracking()
                    return nil
                }
                return event
            }

            var monitors: [Any] = []
            if let local = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown],
                handler: handler
            ) {
                monitors.append(local)
            }
            if let global = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown],
                handler: { _ in menu.cancelTracking() }
            ) {
                monitors.append(global)
            }
            return monitors
        }

        private func keyEquivalent(for actionID: MenuBarPanelActionID) -> String {
            switch actionID {
            case .settings:
                ","
            case .quit:
                "q"
            default:
                ""
            }
        }
    }
}
