import AppKit

extension KeyameleonApplicationDelegate {
    @objc
    func openKeyameleon(_ sender: Any?) {
        setupModel.beginGuidedSetup()
        closeMenuBarPanel()
        NSApp.activate(ignoringOtherApps: true)

        if windowController == nil {
            windowController = KeyameleonWindowController(
                model: setupModel,
                switching: activityTriggeredSwitching
            )
        }

        windowController?.showWindow(sender)
        windowController?.window?.orderFrontRegardless()
    }

    func presentSettingsAfterGuidedSetup() {
        openSettings(nil)
        windowController?.close()
    }

    @objc
    func continueSetup(_ sender: Any?) {
        openKeyameleon(sender)
    }
}
