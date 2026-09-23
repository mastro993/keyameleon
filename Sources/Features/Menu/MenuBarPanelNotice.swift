import Foundation

struct MenuBarPanelNotice: Equatable, Sendable {
    let title: String
    let detail: String
    let action: MenuBarPanelContent.Action?

    static func make(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        isSetupComplete: Bool
    ) -> MenuBarPanelNotice? {
        switch outcome.switchingStatus {
        case .permissionRequired:
            return MenuBarPanelNotice(
                title: "Permission Required",
                detail: "Keyameleon needs Input Monitoring to observe Activation Activity.",
                action: outcome.hasAction(.requestPermission)
                    ? MenuBarPanelContent.Action(
                        id: .requestPermission,
                        title: "Request Permission",
                        isEnabled: true,
                        closesPanel: false
                    )
                    : nil
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
                detail = "\(reason) Activity-Triggered Switching resumes automatically."
            } else {
                detail = "Activity-Triggered Switching resumes automatically."
            }
            return MenuBarPanelNotice(title: "Temporarily Unavailable", detail: detail, action: nil)
        case .paused:
            return nil
        case .ready:
            if let warning = outcome.warnings.first(where: { $0.category == .selectionFailed }) {
                let detail = warning.physicalKeyboardName.map {
                    "Retry the Keyboard Assignment for \($0)."
                } ?? "Retry the Keyboard Assignment."
                return MenuBarPanelNotice(
                    title: "Couldn't select the Keyboard Assignment",
                    detail: detail,
                    action: outcome.hasAction(.retryNow)
                        ? MenuBarPanelContent.Action(
                            id: .retryNow,
                            title: "Retry Now",
                            isEnabled: true,
                            closesPanel: false
                        )
                        : nil
                )
            }

            if let mismatch = outcome.mismatch {
                let detail: String
                if let keyboardName = outcome.activePhysicalKeyboard?.name {
                    detail = "The current Input Source is \(sentence(mismatch.currentName)) \(keyboardName)'s Keyboard Assignment is \(sentence(mismatch.assignedName))"
                } else {
                    detail = "The current Input Source is \(sentence(mismatch.currentName)) The Keyboard Assignment is \(sentence(mismatch.assignedName))"
                }
                return MenuBarPanelNotice(title: "Input Source differs", detail: detail, action: nil)
            }

            let unassignedNames = physicalKeyboards
                .filter { $0.assignmentState == .unassigned }
                .map(\.name)
            if let firstName = unassignedNames.first {
                let detail: String
                switch unassignedNames.count {
                case 1:
                    detail = "\(firstName) has no Keyboard Assignment."
                case 2:
                    detail = "\(firstName) and \(unassignedNames[1]) have no Keyboard Assignment."
                default:
                    detail = "\(unassignedNames.count) Physical Keyboards have no Keyboard Assignment."
                }
                return MenuBarPanelNotice(title: "Keyboard Assignment needed", detail: detail, action: nil)
            }

            if !isSetupComplete {
                return MenuBarPanelNotice(
                    title: "Guided setup is not finished",
                    detail: "Open Settings to assign an Input Source.",
                    action: nil
                )
            }
            return nil
        }
    }

    private static func sentence(_ name: String) -> String {
        name.hasSuffix(".") ? name : "\(name)."
    }
}
