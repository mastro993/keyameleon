import SwiftUI

enum MenuBarPanelShortcut: String, Equatable, Sendable {
    case switching = "p"
    case settings = ","
    case quit = "q"

    var title: String { "⌘" + rawValue.uppercased() }
    var key: KeyEquivalent { KeyEquivalent(Character(rawValue)) }
    var modifiers: EventModifiers { .command }
}

extension MenuBarPanelActionID {
    var shortcut: MenuBarPanelShortcut? {
        switch self {
        case .pause, .resume: .switching
        case .settings: .settings
        case .quit: .quit
        case .requestPermission, .about, .openSystemSettings, .checkAgain, .retryNow, .continueSetup: nil
        }
    }
}
