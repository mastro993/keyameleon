import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case requestPermission
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
    static let panelWidth: CGFloat = 320

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

    var assignmentList: MenuBarAssignmentList
    var noticeItems: [Item]
    var footerItems: [Item]

    var items: [Item] {
        noticeItems + footerItems
    }

    var titles: [String] {
        [assignmentList.heading]
            + [assignmentList.emptyTitle, assignmentList.emptyDescription].compactMap { $0 }
            + noticeItems.map(\.title)
            + footerItems.map(\.title)
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
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSourceNames: [PhysicalKeyboardRecordID: String],
        isSetupComplete: Bool,
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool
    ) {
        assignmentList = MenuBarAssignmentList(
            physicalKeyboards: physicalKeyboards,
            assignedInputSourceNames: assignedInputSourceNames
        )

        var noticeItems: [Item] = []
        let switchingStatus = Self.switchingStatusName(outcome.switchingStatus)
        noticeItems.append(
            Item(
                id: "switching-status",
                title: "Switching Status: \(switchingStatus)",
                kind: .status,
                accessibilityLabel: "Switching Status",
                accessibilityValue: switchingStatus
            )
        )

        if outcome.hasAction(.requestPermission) {
            noticeItems.append(
                Item(
                    id: MenuBarPanelActionID.requestPermission.rawValue,
                    title: "Request Permission",
                    kind: .action(.requestPermission, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        if let reason = outcome.temporarilyUnavailableReasons.first {
            let reasonName = Self.unavailableReasonName(reason)
            noticeItems.append(
                Item(
                    id: "unavailable-reason",
                    title: "Detected reason: \(reasonName)",
                    kind: .status,
                    accessibilityLabel: "Detected reason:",
                    accessibilityValue: reasonName
                )
            )
            noticeItems.append(
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
            noticeItems.append(
                Item(
                    id: "unclean-exit",
                    title: "Keyameleon did not exit cleanly.",
                    kind: .status,
                    accessibilityLabel: "Keyameleon did not exit cleanly.",
                    accessibilityValue:
                        "Review local Diagnostic Data. Keyameleon sends no notification for an unclean exit."
                )
            )
            noticeItems.append(
                Item(
                    id: MenuBarPanelActionID.reviewDiagnostics.rawValue,
                    title: "Review Diagnostics…",
                    kind: .action(.reviewDiagnostics, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
            noticeItems.append(
                Item(
                    id: MenuBarPanelActionID.dismissDiagnosticsNotice.rawValue,
                    title: "Dismiss Diagnostics Notice",
                    kind: .action(.dismissDiagnosticsNotice, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        var footerItems: [Item] = []
        if outcome.hasAction(.resume) {
            footerItems.append(
                Item(
                    id: MenuBarPanelActionID.resume.rawValue,
                    title: "Resume Activity-Triggered Switching",
                    kind: .action(.resume, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        } else if outcome.hasAction(.pause) {
            footerItems.append(
                Item(
                    id: MenuBarPanelActionID.pause.rawValue,
                    title: "Pause Activity-Triggered Switching",
                    kind: .action(.pause, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        footerItems.append(
            Item(
                id: MenuBarPanelActionID.openKeyameleon.rawValue,
                title: "Open Keyameleon…",
                kind: .action(.openKeyameleon, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )

        if !isSetupComplete {
            footerItems.append(
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
            footerItems.append(
                Item(
                    id: MenuBarPanelActionID.openSystemSettings.rawValue,
                    title: "Open System Settings",
                    kind: .action(.openSystemSettings, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
            footerItems.append(
                Item(
                    id: MenuBarPanelActionID.checkAgain.rawValue,
                    title: "Check Again",
                    kind: .action(.checkAgain, enabled: true),
                    accessibilityLabel: nil,
                    accessibilityValue: nil
                )
            )
        }

        footerItems.append(
            Item(
                id: MenuBarPanelActionID.settings.rawValue,
                title: "Settings…",
                kind: .action(.settings, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )
        footerItems.append(
            Item(
                id: MenuBarPanelActionID.checkForUpdates.rawValue,
                title: "Check for Updates…",
                kind: .action(.checkForUpdates, enabled: canCheckForUpdates),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )
        footerItems.append(
            Item(
                id: MenuBarPanelActionID.quit.rawValue,
                title: "Quit Keyameleon",
                kind: .action(.quit, enabled: true),
                accessibilityLabel: nil,
                accessibilityValue: nil
            )
        )

        self.noticeItems = noticeItems
        self.footerItems = footerItems
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
}
