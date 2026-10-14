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

    /// The symbol the sidebar shows. A selected section takes the filled variant.
    func systemImage(isSelected: Bool) -> String {
        switch self {
        case .general: isSelected ? "gearshape.fill" : "gearshape"
        case .keyboards: isSelected ? "keyboard.fill" : "keyboard"
        case .apps: isSelected ? "square.grid.2x2.fill" : "square.grid.2x2"
        case .about: isSelected ? "info.circle.fill" : "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsSelection {
    var section: SettingsSection = .general
}
