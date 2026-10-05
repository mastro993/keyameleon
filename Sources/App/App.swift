import SwiftUI

@main
struct KeyameleonApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                model: applicationDelegate.generalSettingsModel,
                setupModel: applicationDelegate.setupModel,
                selection: applicationDelegate.settingsSelection
            )
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Keyameleon") {
                    applicationDelegate.openAbout(nil)
                }
            }
        }
    }
}
