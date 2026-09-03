import AppKit
import SwiftUI

@MainActor
final class KeyameleonSettingsWindowController: NSWindowController {
    private let selection: KeyameleonSettingsSelection

    var selectedSection: KeyameleonSettingsSection {
        selection.section
    }

    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel,
        selection: KeyameleonSettingsSelection
    ) {
        self.selection = selection
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyameleon - Settings"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.settings-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 540)
        window.contentView = NSHostingView(
            rootView: KeyameleonSettingsView(
                model: model,
                setupModel: setupModel,
                selection: selection
            )
        )

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }
        super.showWindow(sender)
        window.makeKeyAndOrderFront(sender)
    }
}

@MainActor
final class KeyameleonWindowController: NSWindowController {
    init(
        model: KeyameleonSetupModel,
        switching: ActivityTriggeredSwitching,
        diagnosticModel: KeyameleonGeneralSettingsModel
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyameleon"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.main-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 280)
        window.contentView = NSHostingView(
            rootView: KeyameleonRootView(
                model: model,
                switching: switching,
                diagnosticModel: diagnosticModel
            )
        )

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        guard let window else {
            return
        }

        window.center()
        super.showWindow(sender)
        window.makeKeyAndOrderFront(sender)
    }
}
