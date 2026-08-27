import SwiftUI

@main
struct KeyameleonApp: App {
    @NSApplicationDelegateAdaptor(KeyameleonApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        Settings {
            KeyameleonGeneralSettingsView(model: applicationDelegate.generalSettingsModel)
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
