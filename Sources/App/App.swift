import SwiftUI

@main
struct KeyameleonApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        // The App protocol needs a scene; ⌘, opens the toolbar Settings window instead.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {}
            CommandGroup(replacing: .appSettings) {
                Button(.settings) {
                    applicationDelegate.openSettings(nil)
                }
                .keyboardShortcut(",")
            }
        }
    }
}
