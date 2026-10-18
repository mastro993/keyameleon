import Foundation

/// A device that can produce Activation Activity is a Physical Keyboard.
struct PhysicalKeyboardHIDRecognition: Equatable, Sendable {
    var hasKeyInputUsage: Bool
    var hasKeyInputElement: Bool

    var isPhysicalKeyboard: Bool {
        hasKeyInputUsage || hasKeyInputElement
    }
}
