import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case requestPermission
    case openSystemSettings
    case relaunch
    case retryNow
    case switchBackNow
    case retryPersistence
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

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource],
        marketingVersion: String?,
        appName: String = AppIdentity.current.name,
        canCheckForUpdates: Bool
    ) {
        self.switchingStatus = outcome.switchingStatus
        let trimmedVersion = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let version = trimmedVersion.isEmpty ? "—" : trimmedVersion
        let heading = "\(appName) v\(version)"
        self.headerTitle = outcome.switchingStatus == .paused
            ? String(localized: .menuHeaderPaused(heading))
            : heading
        self.notice = MenuBarPanelNotice.make(
            outcome: outcome,
            physicalKeyboards: physicalKeyboards
        )
        self.assignmentList = MenuBarAssignmentList(
            physicalKeyboards: physicalKeyboards,
            assignedInputSources: assignedInputSources,
            frontmostAppAssignment: outcome.frontmostAppAssignment
        )
        self.footer = Footer(
            actions: Self.makeActions(
                outcome: outcome,
                canCheckForUpdates: canCheckForUpdates,
                appName: appName
            )
        )
    }

    private static func makeActions(
        outcome: ActivityTriggeredSwitchingOutcome,
        canCheckForUpdates: Bool,
        appName: String
    ) -> [Action] {
        var actions = [Action]()
        actions.append(pauseOrResume(outcome: outcome))
        if outcome.hasAction(.relaunch) {
            actions.append(Action(id: .relaunch, title: String(localized: .restartApp(appName)), isEnabled: true))
        }
        actions.append(Action(id: .settings, title: String(localized: .settings), isEnabled: true))
        actions.append(Action(
            id: .checkForUpdates,
            title: String(localized: .checkForUpdates),
            isEnabled: canCheckForUpdates
        ))
        actions.append(Action(id: .quit, title: String(localized: .quitApp(appName)), isEnabled: true))
        return actions
    }

    private static func pauseOrResume(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> Action {
        if outcome.hasAction(.resume) {
            return Action(
                id: .resume,
                title: String(localized: .resumeSwitching),
                isEnabled: true
            )
        }

        return Action(
            id: .pause,
            title: String(localized: .pauseSwitching),
            isEnabled: true
        )
    }
}
