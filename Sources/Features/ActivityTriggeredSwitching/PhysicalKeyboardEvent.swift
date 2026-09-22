import Foundation

/// An observable input-state change or repeat attributed to one Physical Keyboard.
/// Key Content is not retained after Activation Activity classification.
enum PhysicalKeyboardEventKind: Equatable, Sendable {
    case press
    case `repeat`
    case release
}

struct PhysicalKeyboardEvent: Equatable, Sendable {
    let serviceID: UInt64
    let kind: PhysicalKeyboardEventKind
}

enum ActivationActivityClassification {
    /// Press and repeat are Activation Activity. Release-only is not.
    static func isActivationActivity(_ kind: PhysicalKeyboardEventKind) -> Bool {
        switch kind {
        case .press, .repeat:
            true
        case .release:
            false
        }
    }

    static func isActivationActivity(_ event: PhysicalKeyboardEvent) -> Bool {
        isActivationActivity(event.kind)
    }
}

/// Derives Physical Keyboard Event kind from consecutive element values.
/// Non-zero means the exposed key is down. Key Content is not returned.
enum PhysicalKeyboardElementTransition {
    static func kind(previous: Int64?, current: Int64) -> PhysicalKeyboardEventKind? {
        let wasDown = (previous ?? 0) != 0
        let isDown = current != 0

        switch (wasDown, isDown) {
        case (false, true):
            return .press
        case (true, true):
            return .repeat
        case (true, false):
            return .release
        case (false, false):
            return nil
        }
    }
}
