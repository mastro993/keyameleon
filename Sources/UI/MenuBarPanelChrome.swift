import Foundation

enum MenuBarPanelChrome: Equatable, Sendable {
    enum Surface: Equatable, Sendable {
        case nativeGlass
        case opaque
    }

    static func surface(reduceTransparency: Bool) -> Surface {
        reduceTransparency ? .opaque : .nativeGlass
    }

    static func prefersEmphasizedSeparators(increaseContrast: Bool) -> Bool {
        increaseContrast
    }
}
