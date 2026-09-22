import AppKit

extension KeyameleonApplicationDelegate {
    @objc
    func openSettings(_ sender: Any?) {
        presentSettings(section: nil)
    }

    private func presentSettings(section: KeyameleonSettingsSection?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()
        if let section {
            settingsSelection.section = section
        }
        if settingsWindowController == nil {
            settingsWindowController = KeyameleonSettingsWindowController(
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
