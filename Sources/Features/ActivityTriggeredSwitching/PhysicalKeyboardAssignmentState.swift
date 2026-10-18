import Foundation

enum PhysicalKeyboardAssignmentState: Equatable, Sendable {
    case unassigned
    case assigned(KeyboardAssignment)
    case unsupported(PhysicalKeyboardUnsupportedReason)
}
