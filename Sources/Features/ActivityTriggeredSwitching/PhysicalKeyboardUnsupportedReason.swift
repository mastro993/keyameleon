import Foundation

enum PhysicalKeyboardUnsupportedReason: Equatable, Sendable {
    case missingIdentity
    case unstableIdentity
    case sharedIdentity
    case ambiguousIdentity
}
