import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case openKeyameleon
    case continueSetup
    case openSystemSettings
    case checkAgain
    case settings
    case checkForUpdates
    case quit
    case reviewDiagnostics
    case dismissDiagnosticsNotice
}

/// Typed Menu first rows and actions for the live menu-bar panel.
struct MenuBarPanelContent: Equatable, Sendable {
    static let panelWidth: CGFloat = 360

    struct Item: Equatable, Identifiable, Sendable {
        enum Kind: Equatable, Sendable {
            case status
            case action(MenuBarPanelActionID, enabled: Bool)
        }

        let id: String
        let title: String
        let kind: Kind
        let accessibilityLabel: String?
        let accessibilityValue: String?
    }

    var items: [Item]

    var titles: [String] {
        items.map(\.title)
    }

    var actionTitles: [String] {
        items.compactMap { item in
            if case .action = item.kind {
                return item.title
            }
            return nil
        }
    }

    var panelWidth: CGFloat {
        Self.panelWidth
    }

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        actionConditions: [PhysicalKeyboardActionCondition],
        isSetupComplete: Bool,
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool
    ) {
        var items: [Item] = []
        let switchingStatus = Self.switchingStatusName(outcome.switchingStatus)
        items.append(
            Item(
                id: "switching-status",
                title: "Switching Status: \(switchingStatus)",
                kind: .status,
                accessibilityLabel: "Switching Status",
                accessibilityValue: switchingStatus
            )
        )

        if let reason = outcome.temporarilyUnavailableReasons.first {
            let reasonName = Self.unavailableReasonName(reason)
            items.append(
                Item(
                    id: "unavailable-reason",
                    title: "Detected reason: \(reasonName)",
                    kind: .status,
                    accessibilityLabel: "Detected reason:",
                    accessibilityValue: reasonName
                )
            )
            items.append(
                Item(
                    id: "unavailable-recovery",
                    title: "Resumes automatically when macOS allows Activity-Triggered Switching.",
                    kind: .status,
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        if hasPendingUncleanExitNotice {
            items.append(
                Item(
                    id: "unclean-exit",
                    title: "Keyameleon did not exit cleanly.",
                    kind: .status,
                    accessibilityLabel: "Keyameleon did not exit cleanly.",
                    accessibilityValue:
                        "Review local Diagnostic Data. Keyameleon sends no notification for an unclean exit."
                )
            )
            items.append(
                Item(
                    id: MenuBarPanelActionID.reviewDiagnostics.rawValue,
                    title: "Review Diagnostics…",
                    kind: .action(.reviewDiagnostics, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
            items.append(
                Item(
                    id: MenuBarPanelActionID.dismissDiagnosticsNotice.rawValue,
                    title: "Dismiss Diagnostics Notice",
                    kind: .action(.dismissDiagnosticsNotice, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        let activePhysicalKeyboardValue =
            outcome.activePhysicalKeyboard?.name ?? "No activity observed yet"
        items.append(
            Item(
                id: "active-physical-keyboard",
                title: "Active Physical Keyboard: \(activePhysicalKeyboardValue)",
                kind: .status,
                accessibilityLabel: "Active",
                accessibilityValue: activePhysicalKeyboardValue
            )
        )

        let assignmentValue = Self.keyboardAssignmentValue(outcome.currentKeyboardAssignment)
        items.append(
            Item(
                id: "keyboard-assignment",
                title: "Keyboard Assignment: \(assignmentValue)",
                kind: .status,
                accessibilityLabel: "Keyboard Assignment",
                accessibilityValue: assignmentValue
            )
        )

        let currentInputSourceValue = outcome.currentInputSourceName ?? "—"
        items.append(
            Item(
                id: "current-input-source",
                title: "Current Input Source: \(currentInputSourceValue)",
                kind: .status,
                accessibilityLabel: "Current Input Source",
                accessibilityValue: currentInputSourceValue
            )
        )

        if let mismatch = outcome.mismatch {
            items.append(
                Item(
                    id: "assigned-input-source",
                    title: "Assigned Input Source: \(mismatch.assignedName)",
                    kind: .status,
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
            items.append(
                Item(
                    id: "restore-assignment",
                    title: "Later Activation Activity restores the Keyboard Assignment.",
                    kind: .status,
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        for actionCondition in actionConditions {
            let title = Self.actionConditionTitle(actionCondition)
            items.append(
                Item(
                    id: "action-condition-\(title)",
                    title: title,
                    kind: .status,
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        if outcome.hasAction(.resume) {
            items.append(
                Item(
                    id: MenuBarPanelActionID.resume.rawValue,
                    title: "Resume Activity-Triggered Switching",
                    kind: .action(.resume, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        } else if outcome.hasAction(.pause) {
            items.append(
                Item(
                    id: MenuBarPanelActionID.pause.rawValue,
                    title: "Pause Activity-Triggered Switching",
                    kind: .action(.pause, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        items.append(
            Item(
                id: MenuBarPanelActionID.openKeyameleon.rawValue,
                title: "Open Keyameleon…",
                kind: .action(.openKeyameleon, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )

        if !isSetupComplete {
            items.append(
                Item(
                    id: MenuBarPanelActionID.continueSetup.rawValue,
                    title: "Continue Setup…",
                    kind: .action(.continueSetup, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        if outcome.hasAction(.openSystemSettings) && outcome.hasAction(.checkAgain) {
            items.append(
                Item(
                    id: MenuBarPanelActionID.openSystemSettings.rawValue,
                    title: "Open System Settings",
                    kind: .action(.openSystemSettings, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
            items.append(
                Item(
                    id: MenuBarPanelActionID.checkAgain.rawValue,
                    title: "Check Again",
                    kind: .action(.checkAgain, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        items.append(
            Item(
                id: MenuBarPanelActionID.settings.rawValue,
                title: "Settings…",
                kind: .action(.settings, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )
        items.append(
            Item(
                id: MenuBarPanelActionID.checkForUpdates.rawValue,
                title: "Check for Updates…",
                kind: .action(.checkForUpdates, enabled: canCheckForUpdates),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )
        items.append(
            Item(
                id: MenuBarPanelActionID.quit.rawValue,
                title: "Quit Keyameleon",
                kind: .action(.quit, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )

        self.items = items
    }

    private static func keyboardAssignmentValue(
        _ assignment: ActivityTriggeredSwitchingKeyboardAssignment
    ) -> String {
        switch assignment {
        case .none:
            "—"
        case .unassigned:
            "Unassigned"
        case let .assigned(name):
            name
        case .unavailable:
            "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            "Unsupported — \(unsupportedReasonName(reason))"
        }
    }

    private static func switchingStatusName(_ status: SwitchingStatus) -> String {
        switch status {
        case .ready:
            "Ready"
        case .permissionRequired:
            "Permission Required"
        case .paused:
            "Paused"
        case .temporarilyUnavailable:
            "Temporarily Unavailable"
        }
    }

    private static func unavailableReasonName(_ reason: SwitchingUnavailableReason) -> String {
        switch reason {
        case .sleeping:
            "macOS is asleep"
        case .inactiveSession:
            "The user session is inactive"
        case .secureInput:
            "Secure Input is active"
        case .protectedDataUnavailable:
            "Protected data is unavailable"
        }
    }

    private static func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
        switch reason {
        case .missingIdentity:
            "Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Physical Keyboard Identity ambiguous"
        }
    }

    private static func actionConditionTitle(
        _ condition: PhysicalKeyboardActionCondition
    ) -> String {
        switch condition {
        case let .unassigned(name):
            "Needs action: \(name) — Unassigned"
        case let .unavailableKeyboardAssignment(name):
            "Needs action: \(name) — Unavailable Keyboard Assignment"
        }
    }
}
