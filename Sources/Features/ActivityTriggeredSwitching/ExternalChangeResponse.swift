import Foundation

/// The person's global choice of how Activity-Triggered Switching reacts to an
/// External Input Source Change. It is saved; the Input Source Hold it starts
/// is not.
enum ExternalChangeResponse: String, CaseIterable, Sendable {
    /// No Input Source Hold: the next Activation Activity applies the Keyboard Assignment.
    case switchBack
    /// The hold ends on Activation Activity from a Physical Keyboard whose
    /// Keyboard Assignment equals the current Input Source.
    case holdUntilMatch
    /// The hold ends on Activation Activity from a Physical Keyboard other
    /// than the holding one.
    case holdUntilKeyboardChange
}
