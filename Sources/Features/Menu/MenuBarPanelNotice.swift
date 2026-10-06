import Foundation

struct MenuBarPanelNotice: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case warning
        case neutral
    }

    let title: String
    let detail: String
    let action: MenuBarPanelContent.Action
    let tone: Tone

    static func make(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        isSetupComplete: Bool
    ) -> MenuBarPanelNotice? {
        switch outcome.switchingStatus {
        case .permissionRequired:
            return MenuBarPanelNotice(
                title: "Input Monitoring required",
                detail: "Enable \(AppIdentity.current.name) in Input Monitoring.",
                action: permissionAction(outcome: outcome),
                tone: .warning
            )
        case .temporarilyUnavailable:
            let reason: String?
            if outcome.temporarilyUnavailableReasons.contains(.sleeping) {
                reason = "The Mac is sleeping."
            } else if outcome.temporarilyUnavailableReasons.contains(.inactiveSession) {
                reason = "The session is locked."
            } else if outcome.temporarilyUnavailableReasons.contains(.secureInput) {
                reason = "Secure Input is active."
            } else if outcome.temporarilyUnavailableReasons.contains(.protectedDataUnavailable) {
                reason = "Protected data is unavailable."
            } else {
                reason = nil
            }
            let detail: String
            if let reason {
                detail = "\(reason) Switching resumes automatically."
            } else {
                detail = "Switching resumes automatically."
            }
            return MenuBarPanelNotice(
                title: "Switching unavailable",
                detail: detail,
                action: settingsAction,
                tone: .neutral
            )
        case .paused:
            return nil
        case .ready:
            if let warning = outcome.warnings.first(where: { $0.category == .selectionFailed }) {
                let canRetry = outcome.hasAction(.retryNow)
                let detail = warning.physicalKeyboardName.map {
                    canRetry ? "Try again for \($0)." : "Check \($0)'s Keyboard Assignment."
                } ?? (canRetry ? "Try again." : "Check the Keyboard Assignment.")
                return MenuBarPanelNotice(
                    title: "Couldn't switch Input Source",
                    detail: detail,
                    action: canRetry
                        ? MenuBarPanelContent.Action(
                            id: .retryNow,
                            title: "Retry Now",
                            isEnabled: true
                        )
                        : settingsAction,
                    tone: .neutral
                )
            }

            if let mismatch = outcome.mismatch {
                let detail: String
                if let keyboardName = outcome.activePhysicalKeyboard?.name {
                    detail = """
                    \(keyboardName) is using \(mismatch.currentName) instead of \(sentence(mismatch.assignedName))
                    """
                } else {
                    detail = """
                    Using \(mismatch.currentName) instead of \(sentence(mismatch.assignedName))
                    """
                }
                return MenuBarPanelNotice(
                    title: "Input Source differs",
                    detail: detail,
                    action: settingsAction,
                    tone: .neutral
                )
            }

            let unassignedNames = physicalKeyboards
                .filter { $0.assignmentState == .unassigned }
                .map(\.name)
            if let firstName = unassignedNames.first {
                let detail: String
                switch unassignedNames.count {
                case 1:
                    detail = "Assign an Input Source to \(firstName)."
                case 2:
                    detail = "Assign Input Sources to \(firstName) and \(unassignedNames[1])."
                default:
                    detail = "Assign Input Sources to \(unassignedNames.count) Physical Keyboards."
                }
                return MenuBarPanelNotice(
                    title: "Assign an Input Source",
                    detail: detail,
                    action: settingsAction,
                    tone: .neutral
                )
            }

            if !isSetupComplete {
                return MenuBarPanelNotice(
                    title: "Finish Guided Setup",
                    detail: "Continue where you left off.",
                    action: .init(id: .continueSetup, title: "Continue Guided Setup", isEnabled: true),
                    tone: .neutral
                )
            }
            return nil
        }
    }

    private static func permissionAction(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> MenuBarPanelContent.Action {
        if outcome.hasAction(.openSystemSettings) {
            return MenuBarPanelContent.Action(
                id: .openSystemSettings,
                title: "Open System Settings",
                isEnabled: true
            )
        }
        if outcome.hasAction(.requestPermission) {
            return MenuBarPanelContent.Action(
                id: .requestPermission,
                title: "Request Permission",
                isEnabled: true
            )
        }
        return settingsAction
    }

    private static let settingsAction = MenuBarPanelContent.Action(
        id: .settings,
        title: "Open Settings",
        isEnabled: true
    )

    private static func sentence(_ name: String) -> String {
        name.hasSuffix(".") ? name : "\(name)."
    }
}
