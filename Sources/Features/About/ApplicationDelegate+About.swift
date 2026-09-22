import AppKit

extension KeyameleonApplicationDelegate {
    @objc
    func openAbout(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()

        if aboutWindowController == nil {
            aboutWindowController = KeyameleonAboutWindowController(
                model: generalSettingsModel
            )
        }

        aboutWindowController?.showWindow(sender)
        aboutWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func checkForUpdates(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.checkForUpdates()
        refreshMenuBarPresentation()
    }
}
