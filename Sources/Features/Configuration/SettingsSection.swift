import Observation

enum KeyameleonSettingsSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case keyboards
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .keyboards: "Keyboards"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .keyboards: "keyboard"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class KeyameleonSettingsSelection {
    var section: KeyameleonSettingsSection = .general
}
