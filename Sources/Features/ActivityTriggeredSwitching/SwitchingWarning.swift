import Foundation

/// Typed failure category. Never a raw platform error.
enum SwitchingFailureCategory: Equatable, Sendable {
    case selectionFailed
    case unavailableKeyboardAssignment
    case unavailableAppAssignment
}

/// Explicit recovery the user can take for an active warning.
enum SwitchingRecoveryAction: Equatable, Sendable {
    case retryNow
    case changeOrRemoveAssignment
}

/// One active cause of switching trouble. Repeated Physical Keyboard Events share this warning.
struct SwitchingWarning: Identifiable, Equatable, Sendable {
    enum Cause: Hashable, Sendable {
        /// Exact Input Source selection or readback failed for the current Wanted Input Source.
        case selectionFailure
        /// Saved Keyboard Assignment whose Input Source is not available.
        case unavailableKeyboardAssignment(PhysicalKeyboardRecordID)
        /// Saved App Assignment, by bundle identifier, whose Input Source is not available.
        case unavailableAppAssignment(String)
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
        case let .unavailableAppAssignment(bundleIdentifier):
            "unavailable-app:\(bundleIdentifier)"
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

    static func unavailableAppAssignment(
        bundleIdentifier: String,
        inputSourceIdentifier: String
    ) -> SwitchingWarning {
        SwitchingWarning(
            cause: .unavailableAppAssignment(bundleIdentifier),
            category: .unavailableAppAssignment,
            recoveryAction: .changeOrRemoveAssignment,
            inputSourceIdentifier: inputSourceIdentifier
        )
    }

    /// The warning for a Wanted Input Source whose assignment is unavailable.
    static func unavailableAssignment(for wanted: WantedInputSource) -> SwitchingWarning {
        switch wanted.origin {
        case let .keyboard(physicalKeyboardID):
            .unavailableKeyboardAssignment(
                physicalKeyboardID: physicalKeyboardID,
                inputSourceIdentifier: wanted.inputSourceIdentifier
            )
        case let .app(bundleIdentifier, _):
            .unavailableAppAssignment(
                bundleIdentifier: bundleIdentifier,
                inputSourceIdentifier: wanted.inputSourceIdentifier
            )
        }
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
