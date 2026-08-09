import AppKit

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowController: KeyameleonWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = makeStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: KeyameleonAppMetadata.displayName)
        menu.autoenablesItems = false

        let openItem = NSMenuItem(
            title: KeyameleonAppMetadata.openMenuItemTitle,
            action: #selector(openKeyameleon(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: KeyameleonAppMetadata.quitMenuItemTitle,
            action: #selector(quitKeyameleon(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func openKeyameleon(_ sender: Any?) {
        if windowController == nil {
            windowController = KeyameleonWindowController()
        }

        windowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func quitKeyameleon(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            return item
        }

        button.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: KeyameleonAppMetadata.displayName
        )
        button.imagePosition = .imageOnly
        button.toolTip = KeyameleonAppMetadata.displayName
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(KeyameleonAppMetadata.menuBarAccessibilityLabel)
        item.menu = makeMenu()
        return item
    }
}
