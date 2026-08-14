import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case requestPermission
    case openKeyameleon
    case openSystemSettings
    case checkAgain
    case settings
    case checkForUpdates
    case quit
}

/// Typed Menu first regions and actions for the live menu-bar panel.
struct MenuBarPanelContent: Equatable, Sendable {
    static let panelWidth: CGFloat = 320

    struct Action: Equatable, Identifiable, Sendable {
        let id: MenuBarPanelActionID
        let title: String
        let isEnabled: Bool
        let closesPanel: Bool
    }

    struct Footer: Equatable, Sendable {
        let versionText: String
        let versionAccessibilityValue: String
        let openKeyameleon: Action
        let overflowActions: [Action]
    }

    let switchingStatus: SwitchingStatus
    let assignmentList: MenuBarAssignmentList
    let footer: Footer

    var accessibility: MenuBarPanelAccessibility {
        MenuBarPanelAccessibility(content: self)
    }

    var actionTitles: [String] {
        [footer.openKeyameleon.title] + footer.overflowActions.map(\.title)
    }

    var panelWidth: CGFloat {
        Self.panelWidth
    }

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSourceNames: [PhysicalKeyboardRecordID: String],
        canCheckForUpdates: Bool,
        marketingVersion: String?
    ) {
        self.switchingStatus = outcome.switchingStatus
        self.assignmentList = MenuBarAssignmentList(
            physicalKeyboards: physicalKeyboards,
            assignedInputSourceNames: assignedInputSourceNames
        )
        let versionParts = Self.versionParts(marketingVersion: marketingVersion)
        self.footer = Footer(
            versionText: versionParts.visible,
            versionAccessibilityValue: versionParts.accessibilityValue,
            openKeyameleon: Action(
                id: .openKeyameleon,
                title: "Open Keyameleon",
                isEnabled: true,
                closesPanel: true
            ),
            overflowActions: Self.makeOverflowActions(
                outcome: outcome,
                canCheckForUpdates: canCheckForUpdates
            )
        )
    }

    static func versionText(marketingVersion: String?) -> String {
        versionParts(marketingVersion: marketingVersion).visible
    }

    private static func versionParts(
        marketingVersion: String?
    ) -> (visible: String, accessibilityValue: String) {
        let trimmed = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return ("Keyameleon —", "—")
        }

        return ("Keyameleon \(trimmed)", trimmed)
    }

    private static func makeOverflowActions(
        outcome: ActivityTriggeredSwitchingOutcome,
        canCheckForUpdates: Bool
    ) -> [Action] {
        var actions = [pauseOrResume(outcome: outcome)]
        actions.append(contentsOf: recoveryActions(outcome: outcome))
        actions.append(
            Action(
                id: .checkForUpdates,
                title: "Check for Updates…",
                isEnabled: canCheckForUpdates,
                closesPanel: true
            )
        )
        actions.append(
            Action(id: .settings, title: "Settings…", isEnabled: true, closesPanel: true)
        )
        actions.append(
            Action(id: .quit, title: "Quit Keyameleon", isEnabled: true, closesPanel: true)
        )
        return actions
    }

    private static func pauseOrResume(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> Action {
        if outcome.hasAction(.resume) {
            return Action(
                id: .resume,
                title: "Resume",
                isEnabled: true,
                closesPanel: false
            )
        }

        return Action(
            id: .pause,
            title: "Pause",
            isEnabled: true,
            closesPanel: false
        )
    }

    private static func recoveryActions(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> [Action] {
        switch outcome.switchingStatus {
        case .ready, .paused:
            return []
        case .permissionRequired, .temporarilyUnavailable:
            break
        }

        var actions: [Action] = []
        if outcome.hasAction(.requestPermission) {
            actions.append(
                Action(
                    id: .requestPermission,
                    title: "Request Permission",
                    isEnabled: true,
                    closesPanel: true
                )
            )
        }
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
}
