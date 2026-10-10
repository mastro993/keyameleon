import Foundation

/// An Input Source Hold in progress. It lives in memory only and is never saved.
enum InputSourceHold: Equatable, Sendable {
    case untilMatch
    /// The holding Physical Keyboard is nil when the External Input Source
    /// Change came before any Activation Activity; the first Physical Keyboard
    /// typed on then becomes the holding one.
    case untilKeyboardChange(holdingPhysicalKeyboardID: PhysicalKeyboardRecordID?)

    /// The External Change Response that started this hold.
    var response: ExternalChangeResponse {
        switch self {
        case .untilMatch: .holdUntilMatch
        case .untilKeyboardChange: .holdUntilKeyboardChange
        }
    }
}
