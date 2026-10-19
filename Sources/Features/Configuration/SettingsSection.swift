import Foundation
import Observation

enum SettingsSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case keyboards
    case apps
    case about

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .general: .settingsGeneral
        case .keyboards: .keyboards
        case .apps: .settingsApps
        case .about: .settingsAbout
        }
    }

    /// The symbol the Settings toolbar shows.
    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .keyboards: "keyboard"
        case .apps: "square.grid.2x2"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsSelection {
    var section: SettingsSection = .general
}
