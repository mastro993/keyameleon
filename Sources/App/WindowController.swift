import AppKit
import SwiftUI

@MainActor
final class KeyameleonSettingsWindowController: NSWindowController {
    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyameleon - Settings"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.settings-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 580, height: 520)
        window.contentView = NSHostingView(
            rootView: KeyameleonSettingsView(
                model: model,
                setupModel: setupModel
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
final class KeyameleonAboutWindowController: NSWindowController {
    init(model: KeyameleonGeneralSettingsModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Keyameleon"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.about-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: KeyameleonAboutView(model: model)
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
        switching: ActivityTriggeredSwitching
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyameleon"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.main-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 520)
        window.contentView = NSHostingView(
            rootView: KeyameleonRootView(
                model: model,
                switching: switching
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
