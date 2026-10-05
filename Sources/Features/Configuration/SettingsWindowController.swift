import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let selection: SettingsSelection

    var selectedSection: SettingsSection {
        selection.section
    }

    init(
        model: GeneralSettingsModel,
        setupModel: SetupModel,
        selection: SettingsSelection
    ) {
        self.selection = selection
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Theme.Metrics.settingsWindowMinimumWidth,
                height: Theme.Metrics.settingsWindowMinimumHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyameleon - Settings"
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.settings-window")
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        // The design draws its own sidebar under the traffic lights.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(
            width: Theme.Metrics.settingsWindowMinimumWidth,
            height: Theme.Metrics.settingsWindowMinimumHeight
        )
        window.contentView = NSHostingView(
            rootView: SettingsView(
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
