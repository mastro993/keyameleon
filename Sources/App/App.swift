import SwiftUI

@main
struct KeyameleonApp: App {
    @NSApplicationDelegateAdaptor(KeyameleonApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        Settings {
            KeyameleonSettingsView(
                model: applicationDelegate.generalSettingsModel,
                setupModel: applicationDelegate.setupModel
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
