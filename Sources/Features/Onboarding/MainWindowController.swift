import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let model: SetupModel
    init(
        model: SetupModel,
        switching: ActivityTriggeredSwitching
    ) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.current.name
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.main-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 840, height: 640)
        window.contentView = NSHostingView(
            rootView: RootView(
                model: model,
                switching: switching
            )
        )

        super.init(window: window)
        window.delegate = self
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
        model.beginGuidedSetup()
        super.showWindow(sender)
        window.makeKeyAndOrderFront(sender)
    }

    func windowWillClose(_ notification: Notification) {
        model.endGuidedSetupPresentation()
    }
}
