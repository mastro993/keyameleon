import AppKit

extension ApplicationDelegate {
    @objc
    func openAbout(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()

        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController(
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
