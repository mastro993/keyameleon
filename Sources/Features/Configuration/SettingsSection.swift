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

    /// The symbol the sidebar shows. A selected section takes the filled variant.
    func systemImage(isSelected: Bool) -> String {
        switch self {
        case .general: isSelected ? "gearshape.fill" : "gearshape"
        case .keyboards: isSelected ? "keyboard.fill" : "keyboard"
        case .about: isSelected ? "info.circle.fill" : "info.circle"
        }
    }
}

@MainActor
@Observable
final class KeyameleonSettingsSelection {
    var section: KeyameleonSettingsSection = .general
}
