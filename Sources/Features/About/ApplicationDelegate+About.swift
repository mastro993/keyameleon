import AppKit

extension KeyameleonApplicationDelegate {
    @objc
    func reviewDiagnostics(_ sender: Any?) {
        closeMenuBarPanel()
        uncleanExitStateStore.dismissUncleanExitNotice()
        generalSettingsModel.refresh()
        if diagnosticReviewWindowController == nil {
            diagnosticReviewWindowController = KeyameleonDiagnosticWindowController(
                model: generalSettingsModel
            )
        }

        diagnosticReviewWindowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        refreshMenuBarPresentation()
    }

    @objc
    func dismissDiagnosticsNotice(_ sender: Any?) {
        uncleanExitStateStore.dismissUncleanExitNotice()
        refreshMenuBarPresentation()
    }

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
