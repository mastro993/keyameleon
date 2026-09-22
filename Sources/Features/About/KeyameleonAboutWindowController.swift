import AppKit
import SwiftUI

@MainActor
final class KeyameleonAboutWindowController: NSWindowController {
    init(model: KeyameleonGeneralSettingsModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
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
