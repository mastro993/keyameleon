enum MenuBarPanelShortcut: String, Equatable, Sendable {
    case switching = "p"
    case settings = ","
    case quit = "q"
}

extension MenuBarPanelActionID {
    var shortcut: MenuBarPanelShortcut? {
        switch self {
        case .pause, .resume: .switching
        case .settings: .settings
        case .quit: .quit
        case .requestPermission, .openSystemSettings, .relaunch,
             .retryNow, .retryPersistence, .checkForUpdates: nil
        }
    }
}
