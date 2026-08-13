import AppKit
import SwiftUI

/// AppKit overflow control so XCUITest can open the footer menu inside the popover.
@MainActor
struct MenuBarOverflowButton: NSViewRepresentable {
    var actions: [MenuBarPanelContent.Action]
    var perform: (MenuBarPanelContent.Action) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "More", target: context.coordinator, action: #selector(Coordinator.showMenu(_:)))
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.setAccessibilityLabel("More")
        button.setAccessibilityIdentifier("menu-bar-panel-overflow")
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.actions = actions
        context.coordinator.perform = perform
    }

    @MainActor
    final class Coordinator: NSObject {
        var actions: [MenuBarPanelContent.Action] = []
        var perform: ((MenuBarPanelContent.Action) -> Void)?

        @objc
        func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for action in actions {
                if action.id == .quit {
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
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        }

        @objc
        func runAction(_ sender: NSMenuItem) {
            guard
                let rawValue = sender.representedObject as? String,
                let actionID = MenuBarPanelActionID(rawValue: rawValue),
                let action = actions.first(where: { $0.id == actionID })
            else {
                return
            }

            perform?(action)
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
