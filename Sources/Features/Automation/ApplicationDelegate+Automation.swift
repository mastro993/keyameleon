import AppIntents
import AppKit

extension ApplicationDelegate {
    /// Lets Shortcuts actions reach the one switching module.
    func registerAutomationDependencies() {
        let switching = activityTriggeredSwitching
        AppDependencyManager.shared.add(dependency: switching)
    }

    /// Handles `keyameleon://` URLs (`keyameleon-dev://` for Debug).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = AutomationCommand(url: url) else {
                Log.warning(.app, "Ignored unknown automation URL")
                continue
            }
            do {
                try command.perform(on: activityTriggeredSwitching)
            } catch {
                switch error {
                case .inputSourceUnavailable:
                    Log.warning(.app, "Automation URL named no available Input Source")
                case .selectionFailed:
                    Log.warning(.app, "macOS did not keep the Input Source an automation URL selected")
                }
            }
        }
    }
}
