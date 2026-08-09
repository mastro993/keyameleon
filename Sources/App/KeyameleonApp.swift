import SwiftUI

@main
struct KeyameleonApp: App {
    @NSApplicationDelegateAdaptor(KeyameleonApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
