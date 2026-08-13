import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case openKeyameleon
    case openSystemSettings
    case checkAgain
    case settings
    case checkForUpdates
    case quit
    case reviewDiagnostics
    case dismissDiagnosticsNotice
}

/// Typed Menu first regions and actions for the live menu-bar panel.
struct MenuBarPanelContent: Equatable, Sendable {
    static let panelWidth: CGFloat = 360

    struct Action: Equatable, Identifiable, Sendable {
        let id: MenuBarPanelActionID
        let title: String
        let isEnabled: Bool
        let closesPanel: Bool
    }

    struct QuickActions: Equatable, Sendable {
        let openKeyameleon: Action
        let pauseOrResume: Action
    }

    struct RecoveryBanner: Equatable, Sendable {
        let statusName: String
        let detailLines: [String]
        let recoveryActions: [Action]
    }

    struct UncleanExitNotice: Equatable, Sendable {
        let title: String
        let dismiss: Action
    }

    struct Footer: Equatable, Sendable {
        let versionText: String
        let overflowActions: [Action]
    }

    struct Item: Equatable, Identifiable, Sendable {
        enum Kind: Equatable, Sendable {
            case status
        }

        let id: String
        let title: String
        let kind: Kind
        let accessibilityLabel: String?
        let accessibilityValue: String?
    }

    let quickActions: QuickActions
    let recoveryBanner: RecoveryBanner?
    let uncleanExitNotice: UncleanExitNotice?
    let statusItems: [Item]
    let footer: Footer

    var statusTitles: [String] {
        statusItems.map(\.title)
    }

    var actionTitles: [String] {
        var titles = [
            quickActions.openKeyameleon.title,
            quickActions.pauseOrResume.title,
        ]
        if let recoveryBanner {
            titles.append(contentsOf: recoveryBanner.recoveryActions.map(\.title))
        }
        if let uncleanExitNotice {
            titles.append(uncleanExitNotice.dismiss.title)
        }
        titles.append(contentsOf: footer.overflowActions.map(\.title))
        return titles
    }

    var panelWidth: CGFloat {
        Self.panelWidth
    }

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        actionConditions: [PhysicalKeyboardActionCondition],
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool,
        marketingVersion: String?
    ) {
        self.quickActions = Self.makeQuickActions(outcome: outcome)
        self.recoveryBanner = Self.makeRecoveryBanner(outcome: outcome)
        self.uncleanExitNotice = Self.makeUncleanExitNotice(
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice
        )
        self.statusItems = Self.makeStatusItems(
            outcome: outcome,
            actionConditions: actionConditions
        )
        self.footer = Footer(
            versionText: Self.versionText(marketingVersion: marketingVersion),
            overflowActions: Self.makeOverflowActions(
                canCheckForUpdates: canCheckForUpdates,
                hasPendingUncleanExitNotice: hasPendingUncleanExitNotice
            )
        )
    }

    static func versionText(marketingVersion: String?) -> String {
        let trimmed = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return "Version —"
        }

        return "Version \(trimmed)"
    }

    private static func makeQuickActions(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> QuickActions {
        let pauseOrResume: Action
        if outcome.hasAction(.resume) {
            pauseOrResume = Action(
                id: .resume,
                title: "Resume",
                isEnabled: true,
                closesPanel: false
            )
        } else {
            pauseOrResume = Action(
                id: .pause,
                title: "Pause",
                isEnabled: true,
                closesPanel: false
            )
        }

        return QuickActions(
            openKeyameleon: Action(
                id: .openKeyameleon,
                title: "Open Keyameleon",
                isEnabled: true,
                closesPanel: true
            ),
            pauseOrResume: pauseOrResume
        )
    }

    private static func makeRecoveryBanner(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> RecoveryBanner? {
        switch outcome.switchingStatus {
        case .ready, .paused:
            return nil
        case .permissionRequired, .temporarilyUnavailable:
            break
        }

        var detailLines: [String] = []
        if let reason = outcome.temporarilyUnavailableReasons.first {
            detailLines.append("Detected reason: \(unavailableReasonName(reason))")
            detailLines.append(
                "Resumes automatically when macOS allows Activity-Triggered Switching."
            )
        }

        return RecoveryBanner(
            statusName: switchingStatusName(outcome.switchingStatus),
            detailLines: detailLines,
            recoveryActions: makeRecoveryActions(outcome: outcome)
        )
    }

    private static func makeRecoveryActions(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> [Action] {
        var actions: [Action] = []
        if outcome.hasAction(.openSystemSettings) {
            actions.append(
                Action(
                    id: .openSystemSettings,
                    title: "Open System Settings",
                    isEnabled: true,
                    closesPanel: true
                )
            )
        }
        if outcome.hasAction(.checkAgain) {
            actions.append(
                Action(
                    id: .checkAgain,
                    title: "Check Again",
                    isEnabled: true,
                    closesPanel: false
                )
            )
        }
        return actions
    }

    private static func makeUncleanExitNotice(
        hasPendingUncleanExitNotice: Bool
    ) -> UncleanExitNotice? {
        guard hasPendingUncleanExitNotice else {
            return nil
        }

        return UncleanExitNotice(
            title: "Keyameleon did not exit cleanly.",
            dismiss: Action(
                id: .dismissDiagnosticsNotice,
                title: "Dismiss Diagnostics Notice",
                isEnabled: true,
                closesPanel: false
            )
        )
    }

    private static func makeOverflowActions(
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool
    ) -> [Action] {
        var actions = [
            Action(id: .settings, title: "Settings…", isEnabled: true, closesPanel: true),
            Action(
                id: .checkForUpdates,
                title: "Check for Updates…",
                isEnabled: canCheckForUpdates,
                closesPanel: true
            ),
        ]
        if hasPendingUncleanExitNotice {
            actions.append(
                Action(
                    id: .reviewDiagnostics,
                    title: "Review Diagnostics…",
                    isEnabled: true,
                    closesPanel: true
                )
            )
        }
        actions.append(
            Action(id: .quit, title: "Quit Keyameleon", isEnabled: true, closesPanel: true)
        )
        return actions
    }

    private static func makeStatusItems(
        outcome: ActivityTriggeredSwitchingOutcome,
        actionConditions: [PhysicalKeyboardActionCondition]
    ) -> [Item] {
        var items: [Item] = []
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

        let assignmentValue = keyboardAssignmentValue(outcome.currentKeyboardAssignment)
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
            let title = actionConditionTitle(actionCondition)
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

        return items
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
