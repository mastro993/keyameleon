import AppKit

extension ApplicationDelegate {
    @objc
    func openSettings(_ sender: Any?) {
        presentSettings(section: nil)
    }

    private func presentSettings(section: SettingsSection?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()
        if let section {
            settingsSelection.section = section
        }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                model: generalSettingsModel,
                setupModel: setupModel,
                selection: settingsSelection
            )
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
