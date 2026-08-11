import Foundation

/// Plain failure category shown to the user. Never a raw platform error.
enum SwitchingFailureCategory: String, Equatable, Sendable {
    case selectionFailed = "Selection failed"
    case unavailableKeyboardAssignment = "Unavailable Keyboard Assignment"

    var displayName: String {
        rawValue
    }
}

/// Explicit recovery the user can take for an active warning.
enum SwitchingRecoveryAction: Equatable, Sendable {
    case retryNow
    case changeOrRemoveAssignment

    var displayName: String {
        switch self {
        case .retryNow:
            "Retry Now"
        case .changeOrRemoveAssignment:
            "Change Assignment or Remove Assignment"
        }
    }
}

/// One active cause of switching trouble. Repeated Physical Keyboard Events share this warning.
struct SwitchingWarning: Identifiable, Equatable, Sendable {
    enum Cause: Hashable, Sendable {
        /// Exact Input Source selection or readback failed for the current wanted Keyboard Assignment.
        case selectionFailure
        /// Saved Keyboard Assignment whose Input Source is not available.
        case unavailableKeyboardAssignment(PhysicalKeyboardRecordID)
    }

    let cause: Cause
    let category: SwitchingFailureCategory
    let recoveryAction: SwitchingRecoveryAction
    /// Exact Input Source identifier involved when known. Never shown as a raw platform error.
    let inputSourceIdentifier: String?

    var id: String {
        switch cause {
        case .selectionFailure:
            "selectionFailure"
        case let .unavailableKeyboardAssignment(physicalKeyboardID):
            "unavailable:\(physicalKeyboardID.rawValue)"
        }
    }

    var supportsRetryNow: Bool {
        recoveryAction == .retryNow
    }

    static func selectionFailure(inputSourceIdentifier: String) -> SwitchingWarning {
        SwitchingWarning(
            cause: .selectionFailure,
            category: .selectionFailed,
            recoveryAction: .retryNow,
            inputSourceIdentifier: inputSourceIdentifier
        )
    }

    static func unavailableKeyboardAssignment(
        physicalKeyboardID: PhysicalKeyboardRecordID,
        inputSourceIdentifier: String
    ) -> SwitchingWarning {
        SwitchingWarning(
            cause: .unavailableKeyboardAssignment(physicalKeyboardID),
            category: .unavailableKeyboardAssignment,
            recoveryAction: .changeOrRemoveAssignment,
            inputSourceIdentifier: inputSourceIdentifier
        )
    }
}

/// Latest wanted Keyboard Assignment for Retry Now and Activation Activity replacement.
struct WantedKeyboardAssignment: Equatable, Sendable {
    let physicalKeyboardID: PhysicalKeyboardRecordID
    let inputSourceIdentifier: String
}

enum KeyboardAssignmentAvailability {
    /// Exact saved Input Source identifier must be present among eligible Input Sources.
    static func isAvailable(
        _ assignment: KeyboardAssignment,
        eligibleIdentifiers: Set<String>
    ) -> Bool {
        eligibleIdentifiers.contains(assignment.inputSourceIdentifier)
    }

    static func isAvailable(
        _ assignment: KeyboardAssignment,
        eligibleInputSources: [EligibleInputSource]
    ) -> Bool {
        isAvailable(
            assignment,
            eligibleIdentifiers: Set(eligibleInputSources.map(\.identifier))
        )
    }
}
