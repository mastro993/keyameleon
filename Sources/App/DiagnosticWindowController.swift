import AppKit
import SwiftUI

@MainActor
final class KeyameleonDiagnosticWindowController: NSWindowController {
    init(model: KeyameleonGeneralSettingsModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = KeyameleonAppMetadata.diagnosticBundleReviewTitle
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.diagnostic-review-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 380)
        window.contentView = NSHostingView(
            rootView: KeyameleonDiagnosticBundleReviewView(model: model)
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
