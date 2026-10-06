import AppKit

extension ApplicationDelegate {
    @objc
    func checkForUpdates(_ sender: Any?) {
        closeMenuBarPanel()
        generalSettingsModel.checkForUpdates()
        refreshMenuBarPresentation()
    }
}
