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
            return permissionNotice(outcome: outcome)
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

    /// Never asked: the macOS alert lists Keyameleon. Asked before: the
    /// person turns it on in System Settings; Restart sits in the commands.
    private static func permissionNotice(outcome: ActivityTriggeredSwitchingOutcome) -> MenuBarPanelNotice {
        let name = AppIdentity.current.name
        if outcome.hasAction(.openSystemSettings) {
            return MenuBarPanelNotice(
                title: "Input Monitoring is off",
                detail: "Turn on \(name) in Input Monitoring. If it is already on, restart \(name).",
                action: .init(id: .openSystemSettings, title: "Open System Settings", isEnabled: true),
                tone: .warning
            )
        }
        return MenuBarPanelNotice(
            title: "Input Monitoring required",
            detail: "\(name) needs it to tell which keyboard you type on.",
            action: outcome.hasAction(.requestPermission)
                ? .init(id: .requestPermission, title: "Allow Input Monitoring…", isEnabled: true)
                : settingsAction,
            tone: .warning
        )
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
