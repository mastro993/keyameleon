import AppKit

extension ApplicationDelegate {
    @objc
    func openSettings(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.refresh()
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                model: generalSettingsModel,
                setupModel: setupModel,
                appAssignmentsModel: appAssignmentsModel,
                selection: settingsSelection
            )
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
