import AppKit
import SwiftUI

@MainActor
final class KeyameleonAboutWindowController: NSWindowController {
    init(model: KeyameleonGeneralSettingsModel) {
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let contentRect = NSWindow.contentRect(
            forFrameRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: styleMask
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "About Keyameleon"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.about-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: KeyameleonCompactAboutView(model: model)
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
