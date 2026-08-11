import Foundation

/// Product-only description of one active Physical Keyboard.
///
/// Internal Physical Keyboard Identity and Input Source identifiers stay inside
/// Activity-Triggered Switching and its adapters.
enum ActivityTriggeredSwitchingKeyboardAssignment: Equatable, Hashable, Sendable {
    case none
    case unassigned
    case assigned(name: String)
    case unavailable
    case unsupported(PhysicalKeyboardUnsupportedReason)
}

struct ActivityTriggeredSwitchingActivePhysicalKeyboard: Equatable, Sendable {
    let name: String
    let connectionState: PhysicalKeyboardConnectionState
    let assignment: ActivityTriggeredSwitchingKeyboardAssignment
}

struct ActivityTriggeredSwitchingMismatch: Equatable, Sendable {
    let currentName: String
    let assignedName: String
}

struct ActivityTriggeredSwitchingWarning: Identifiable, Equatable, Hashable, Sendable {
    let physicalKeyboardName: String?
    let category: SwitchingFailureCategory
    let recoveryAction: SwitchingRecoveryAction

    var id: String {
        [category.rawValue, physicalKeyboardName ?? ""].joined(separator: "|")
    }

    var supportsRetryNow: Bool {
        recoveryAction == .retryNow
    }
}

enum ActivityTriggeredSwitchingAction: Hashable, Sendable {
    case requestPermission
    case openSystemSettings
    case checkAgain
    case pause
    case resume
    case retryNow
}

/// Immutable product outcome published by Activity-Triggered Switching.
///
/// It contains no adapter facts, identifiers, generations, counters, or UI
/// copy. Views translate these product values into user-visible presentation.
struct ActivityTriggeredSwitchingOutcome: Equatable, Sendable {
    let switchingStatus: SwitchingStatus
    let temporarilyUnavailableReasons: [SwitchingUnavailableReason]
    let activePhysicalKeyboard: ActivityTriggeredSwitchingActivePhysicalKeyboard?
    let currentKeyboardAssignment: ActivityTriggeredSwitchingKeyboardAssignment
    let currentInputSourceName: String?
    let mismatch: ActivityTriggeredSwitchingMismatch?
    let warnings: [ActivityTriggeredSwitchingWarning]
    let availableActions: Set<ActivityTriggeredSwitchingAction>

    static let initial = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .permissionRequired,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: nil,
        mismatch: nil,
        warnings: [],
        availableActions: [.requestPermission, .openSystemSettings, .checkAgain]
    )

    func hasAction(_ action: ActivityTriggeredSwitchingAction) -> Bool {
        availableActions.contains(action)
    }
}
