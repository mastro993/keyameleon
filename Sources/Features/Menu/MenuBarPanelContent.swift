import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case requestPermission
    case openSystemSettings
    case relaunch
    case retryNow
    case retryPersistence
    case continueSetup
    case settings
    case checkForUpdates
    case quit
}

/// Typed Menu first regions and actions for the live menu-bar panel.
struct MenuBarPanelContent: Equatable, Sendable {
    static let panelWidth: CGFloat = Theme.Menu.width

    struct Action: Equatable, Identifiable, Sendable {
        let id: MenuBarPanelActionID
        let title: String
        let isEnabled: Bool
    }

    struct Footer: Equatable, Sendable {
        let actions: [Action]
    }

    let headerTitle: String
    let switchingStatus: SwitchingStatus
    let assignmentList: MenuBarAssignmentList
    let footer: Footer
    let notice: MenuBarPanelNotice?

    var actionTitles: [String] {
        footer.actions.map(\.title)
    }

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource],
        marketingVersion: String?,
        appName: String = AppIdentity.current.name,
        isSetupComplete: Bool = true,
        canCheckForUpdates: Bool
    ) {
        self.switchingStatus = outcome.switchingStatus
        let trimmedVersion = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let version = trimmedVersion.isEmpty ? "—" : trimmedVersion
        self.headerTitle = "\(appName) v\(version)"
            + (outcome.switchingStatus == .paused ? " (Paused)" : "")
        self.notice = MenuBarPanelNotice.make(
            outcome: outcome,
            physicalKeyboards: physicalKeyboards,
            isSetupComplete: isSetupComplete
        )
        self.assignmentList = MenuBarAssignmentList(
            physicalKeyboards: physicalKeyboards,
            assignedInputSources: assignedInputSources
        )
        self.footer = Footer(
            actions: Self.makeActions(
                outcome: outcome,
                isSetupComplete: isSetupComplete,
                canCheckForUpdates: canCheckForUpdates,
                appName: appName
            )
        )
    }

    private static func makeActions(
        outcome: ActivityTriggeredSwitchingOutcome,
        isSetupComplete: Bool,
        canCheckForUpdates: Bool,
        appName: String
    ) -> [Action] {
        var actions = [Action]()
        if !isSetupComplete {
            actions.append(Action(
                id: .continueSetup,
                title: "Continue Setup",
                isEnabled: true
            ))
        }
        actions.append(pauseOrResume(outcome: outcome))
        if outcome.hasAction(.relaunch) {
            actions.append(Action(id: .relaunch, title: "Restart \(appName)", isEnabled: true))
        }
        actions.append(Action(id: .settings, title: "Settings", isEnabled: true))
        actions.append(Action(
            id: .checkForUpdates,
            title: "Check for Updates…",
            isEnabled: canCheckForUpdates
        ))
        actions.append(Action(id: .quit, title: "Quit \(appName)", isEnabled: true))
        return actions
    }

    private static func pauseOrResume(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> Action {
        if outcome.hasAction(.resume) {
            return Action(
                id: .resume,
                title: "Resume Switching",
                isEnabled: true
            )
        }

        return Action(
            id: .pause,
            title: "Pause Switching",
            isEnabled: true
        )
    }
}
