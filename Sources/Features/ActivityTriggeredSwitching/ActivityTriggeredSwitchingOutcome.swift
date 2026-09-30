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
        let categoryKey = switch category {
        case .selectionFailed:
            "selection-failed"
        case .unavailableKeyboardAssignment:
            "unavailable-keyboard-assignment"
        }
        return [categoryKey, physicalKeyboardName ?? ""].joined(separator: "|")
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

    static func available(
        for status: SwitchingStatus,
        warnings: [ActivityTriggeredSwitchingWarning],
        isPaused: Bool
    ) -> Set<ActivityTriggeredSwitchingAction> {
        var actions: Set<ActivityTriggeredSwitchingAction>
        switch status {
        case .ready:
            actions = [
                .openSystemSettings,
                .checkAgain
            ]
        case .permissionRequired:
            actions = [.requestPermission, .openSystemSettings, .checkAgain]
        case .paused:
            actions = [.requestPermission, .openSystemSettings, .checkAgain]
        case .temporarilyUnavailable:
            actions = []
        }

        if isPaused {
            actions.insert(.resume)
        } else {
            actions.insert(.pause)
        }
        if status == .ready,
           warnings.contains(where: { $0.recoveryAction == .retryNow }) {
            actions.insert(.retryNow)
        }
        return actions
    }
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

    func replacing(
        status: SwitchingStatus? = nil,
        reasons: [SwitchingUnavailableReason]? = nil,
        isPaused: Bool
    ) -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: status ?? switchingStatus,
            temporarilyUnavailableReasons: reasons ?? temporarilyUnavailableReasons,
            activePhysicalKeyboard: activePhysicalKeyboard,
            currentKeyboardAssignment: currentKeyboardAssignment,
            currentInputSourceName: currentInputSourceName,
            mismatch: mismatch,
            warnings: warnings,
            availableActions: ActivityTriggeredSwitchingAction.available(
                for: status ?? switchingStatus, warnings: warnings, isPaused: isPaused
            )
        )
    }
}
