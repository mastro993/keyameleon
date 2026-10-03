import AppKit

extension KeyameleonApplicationDelegate {
    @objc
    func openKeyameleon(_ sender: Any?) {
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
