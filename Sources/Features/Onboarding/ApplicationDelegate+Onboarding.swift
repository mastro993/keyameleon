import AppKit

extension ApplicationDelegate {
    @objc
    func openKeyameleon(_ sender: Any?) {
        closeMenuBarPanel()
        NSApp.activate(ignoringOtherApps: true)

        if windowController == nil {
            windowController = MainWindowController(
                model: setupModel,
                switching: activityTriggeredSwitching
            )
        }

        windowController?.showWindow(sender)
        windowController?.window?.orderFrontRegardless()
    }

    func finishGuidedSetup(destination: GuidedSetupCompletionDestination) {
        windowController?.close()
        if destination == .settings {
            openSettings(nil)
        }
    }

    @objc
    func continueSetup(_ sender: Any?) {
        openKeyameleon(sender)
    }
}
