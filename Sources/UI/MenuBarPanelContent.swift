import Foundation

enum MenuBarPanelActionID: String, Equatable, Sendable {
    case pause
    case resume
    case openKeyameleon
    case openSystemSettings
    case settings
    case checkForUpdates
    case quit
    case reviewDiagnostics
    case overflow
}

enum MenuBarPanelAssignedInputSource: Equatable, Sendable {
    case available(name: String)
    case unavailable(savedName: String?)
}

enum MenuBarPanelAssignmentConditionMark: Equatable, Sendable {
    case active
    case connected
    case disconnected
}

/// Typed complete menu-bar panel: recovery, Keyboard Assignments, Quick Actions, footer.
struct MenuBarPanelContent: Equatable, Sendable {
    static let panelWidth: CGFloat = 360
    static let visibleAssignmentLimit = 5
    static let assignmentRowMinHeight: CGFloat = 44
    static let fallbackMarketingVersion = "0.1.0"

    struct RecoveryBanner: Equatable, Sendable {
        var switchingStatusName: String
        var detail: String?
        var action: Action?
        var accessibilityLabel: String
        var accessibilityValue: String
    }

    struct AssignmentRow: Equatable, Identifiable, Sendable {
        var id: String
        var physicalKeyboardName: String
        var assignedInputSourceName: String
        var conditionMark: MenuBarPanelAssignmentConditionMark
        var isDimmed: Bool
        var warningNote: String?
        var accessibilityLabel: String
        var accessibilityValue: String
        var accessibilityHint: String?
    }

    struct Action: Equatable, Identifiable, Sendable {
        var id: MenuBarPanelActionID
        var title: String
        var isEnabled: Bool
        var closesPanel: Bool
        var accessibilityLabel: String
    }

    struct AccessibilityAnnouncement: Equatable, Sendable {
        var id: String
        var label: String
        var value: String?
        var hint: String?

        var spoken: String {
            [label, value, hint]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }

    var recoveryBanner: RecoveryBanner?
    var assignmentHeading: String
    var assignmentRows: [AssignmentRow]
    var emptyAssignmentsMessage: String?
    var assignmentsScroll: Bool
    var quickActions: [Action]
    var versionText: String
    var marketingVersion: String
    var overflowActions: [Action]
    var keyboardFocusOrder: [MenuBarPanelActionID]
    var focusSequence: [String]
    var accessibilityAnnouncements: [AccessibilityAnnouncement]

    var panelWidth: CGFloat {
        Self.panelWidth
    }

    init(
        outcome: ActivityTriggeredSwitchingOutcome,
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSources: [PhysicalKeyboardRecordID: MenuBarPanelAssignedInputSource],
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool,
        marketingVersion: String
    ) {
        let resolvedVersion = Self.resolvedMarketingVersion(marketingVersion)
        recoveryBanner = Self.makeRecoveryBanner(outcome: outcome)
        assignmentHeading = "Keyboard Assignments"
        assignmentRows = Self.makeAssignmentRows(
            physicalKeyboards: physicalKeyboards,
            assignedInputSources: assignedInputSources
        )
        emptyAssignmentsMessage = assignmentRows.isEmpty ? "No Keyboard Assignments" : nil
        assignmentsScroll = assignmentRows.count > Self.visibleAssignmentLimit
        quickActions = Self.makeQuickActions(outcome: outcome)
        versionText = "Version \(resolvedVersion)"
        self.marketingVersion = resolvedVersion
        overflowActions = Self.makeOverflowActions(
            canCheckForUpdates: canCheckForUpdates,
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice
        )
        keyboardFocusOrder = Self.makeKeyboardFocusOrder(
            recoveryBanner: recoveryBanner,
            quickActions: quickActions
        )
        focusSequence = Self.makeFocusSequence(
            recoveryBanner: recoveryBanner,
            assignmentRows: assignmentRows,
            quickActions: quickActions
        )
        accessibilityAnnouncements = Self.makeAccessibilityAnnouncements(
            recoveryBanner: recoveryBanner,
            assignmentHeading: assignmentHeading,
            assignmentRows: assignmentRows,
            emptyAssignmentsMessage: emptyAssignmentsMessage,
            quickActions: quickActions,
            version: resolvedVersion,
            overflowActions: overflowActions
        )
    }

    static func marketingVersion(from bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func assignedInputSources(
        from physicalKeyboards: [PhysicalKeyboard],
        names: (PhysicalKeyboard) -> String?
    ) -> [PhysicalKeyboardRecordID: MenuBarPanelAssignedInputSource] {
        Dictionary(
            uniqueKeysWithValues: physicalKeyboards.compactMap { physicalKeyboard in
                guard case .assigned = physicalKeyboard.assignmentState else {
                    return nil
                }

                if let name = names(physicalKeyboard) {
                    return (physicalKeyboard.id, .available(name: name))
                }

                return (physicalKeyboard.id, .unavailable(savedName: nil))
            }
        )
    }
}
