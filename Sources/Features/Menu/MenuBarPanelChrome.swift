import Foundation

enum MenuBarPanelSurface: Equatable, Sendable {
    case liquidGlass
    case opaque
}

enum MenuBarAssignmentEmphasis: Equatable, Sendable {
    case standard
    case highContrast
}

/// Panel chrome for Liquid Glass, Reduce Transparency, and increased contrast.
struct MenuBarPanelChrome: Equatable, Sendable {
    let surface: MenuBarPanelSurface
    let assignmentEmphasis: MenuBarAssignmentEmphasis

    static func resolve(
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> MenuBarPanelChrome {
        MenuBarPanelChrome(
            surface: reduceTransparency ? .opaque : .liquidGlass,
            assignmentEmphasis: increasedContrast ? .highContrast : .standard
        )
    }
}
