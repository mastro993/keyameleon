import Foundation

extension MenuBarPanelContent {
    static func resolvedMarketingVersion(_ marketingVersion: String) -> String {
        let trimmed = marketingVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackMarketingVersion : trimmed
    }

    static func makeRecoveryBanner(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> RecoveryBanner? {
        switch outcome.switchingStatus {
        case .ready, .paused:
            return nil
        case .permissionRequired:
            let action = outcome.hasAction(.openSystemSettings)
                ? Action(
                    id: .openSystemSettings,
                    title: "Open System Settings",
                    isEnabled: true,
                    closesPanel: false,
                    accessibilityLabel: "Open System Settings"
                )
                : nil
            return RecoveryBanner(
                switchingStatusName: "Permission Required",
                detail: nil,
                action: action,
                accessibilityLabel: "Switching Status",
                accessibilityValue: "Permission Required"
            )
        case .temporarilyUnavailable:
            let reason = outcome.temporarilyUnavailableReasons.first.map(unavailableReasonName)
            return RecoveryBanner(
                switchingStatusName: "Temporarily Unavailable",
                detail: reason,
                action: nil,
                accessibilityLabel: "Switching Status",
                accessibilityValue: "Temporarily Unavailable"
            )
        }
    }

    static func makeAssignmentRows(
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSources: [PhysicalKeyboardRecordID: MenuBarPanelAssignedInputSource]
    ) -> [AssignmentRow] {
        let assigned = physicalKeyboards.filter { physicalKeyboard in
            if case .assigned = physicalKeyboard.assignmentState {
                return true
            }

            return false
        }
        let activeID = assigned.first(where: \.isActive)?.id
        return PhysicalKeyboardListOrdering.sorted(assigned, activeID: activeID).map { physicalKeyboard in
            makeAssignmentRow(
                physicalKeyboard,
                inputSource: assignedInputSources[physicalKeyboard.id]
            )
        }
    }

    static func makeAssignmentRow(
        _ physicalKeyboard: PhysicalKeyboard,
        inputSource: MenuBarPanelAssignedInputSource?
    ) -> AssignmentRow {
        let conditionMark: MenuBarPanelAssignmentConditionMark =
            if physicalKeyboard.isActive {
                .active
            } else if physicalKeyboard.connectionState == .disconnected {
                .disconnected
            } else {
                .connected
            }
        let (assignedInputSourceName, warningNote): (String, String?) =
            switch inputSource {
            case let .available(name):
                (name, nil)
            case let .unavailable(savedName):
                (savedName ?? "Unavailable Input Source", "Unavailable Keyboard Assignment")
            case nil:
                ("Unavailable Input Source", "Unavailable Keyboard Assignment")
            }
        let conditionName = switch conditionMark {
        case .active:
            "Active"
        case .connected:
            "Connected"
        case .disconnected:
            "Disconnected"
        }

        return AssignmentRow(
            id: physicalKeyboard.id.rawValue,
            physicalKeyboardName: physicalKeyboard.name,
            assignedInputSourceName: assignedInputSourceName,
            conditionMark: conditionMark,
            isDimmed: conditionMark == .disconnected,
            warningNote: warningNote,
            accessibilityLabel: physicalKeyboard.name,
            accessibilityValue: "\(assignedInputSourceName), \(conditionName)",
            accessibilityHint: warningNote
        )
    }

    static func makeQuickActions(
        outcome: ActivityTriggeredSwitchingOutcome
    ) -> [Action] {
        var actions = [
            Action(
                id: .openKeyameleon,
                title: "Open Keyameleon",
                isEnabled: true,
                closesPanel: true,
                accessibilityLabel: "Open Keyameleon"
            ),
        ]
        if outcome.hasAction(.resume) {
            actions.append(
                Action(
                    id: .resume,
                    title: "Resume",
                    isEnabled: true,
                    closesPanel: false,
                    accessibilityLabel: "Resume Activity-Triggered Switching"
                )
            )
        } else if outcome.hasAction(.pause) {
            actions.append(
                Action(
                    id: .pause,
                    title: "Pause",
                    isEnabled: true,
                    closesPanel: false,
                    accessibilityLabel: "Pause Activity-Triggered Switching"
                )
            )
        }
        return actions
    }

    static func makeOverflowActions(
        canCheckForUpdates: Bool,
        hasPendingUncleanExitNotice: Bool
    ) -> [Action] {
        var actions = [
            Action(
                id: .settings,
                title: "Settings…",
                isEnabled: true,
                closesPanel: true,
                accessibilityLabel: "Settings"
            ),
            Action(
                id: .checkForUpdates,
                title: "Check for Updates…",
                isEnabled: canCheckForUpdates,
                closesPanel: true,
                accessibilityLabel: "Check for Updates"
            ),
        ]
        if hasPendingUncleanExitNotice {
            actions.append(
                Action(
                    id: .reviewDiagnostics,
                    title: "Review Diagnostics…",
                    isEnabled: true,
                    closesPanel: true,
                    accessibilityLabel: "Review Diagnostics"
                )
            )
        }
        actions.append(
            Action(
                id: .quit,
                title: "Quit Keyameleon",
                isEnabled: true,
                closesPanel: true,
                accessibilityLabel: "Quit Keyameleon"
            )
        )
        return actions
    }

    static func makeKeyboardFocusOrder(
        recoveryBanner: RecoveryBanner?,
        quickActions: [Action]
    ) -> [MenuBarPanelActionID] {
        var order: [MenuBarPanelActionID] = []
        if let action = recoveryBanner?.action {
            order.append(action.id)
        }
        order.append(contentsOf: quickActions.map(\.id))
        order.append(.overflow)
        return order
    }

    static func makeFocusSequence(
        recoveryBanner: RecoveryBanner?,
        assignmentRows: [AssignmentRow],
        quickActions: [Action]
    ) -> [String] {
        var order: [String] = []
        if let action = recoveryBanner?.action {
            order.append(action.id.rawValue)
        }
        order.append(contentsOf: assignmentRows.map(\.id))
        order.append(contentsOf: quickActions.map(\.id.rawValue))
        order.append(MenuBarPanelActionID.overflow.rawValue)
        return order
    }

    static func makeAccessibilityAnnouncements(
        recoveryBanner: RecoveryBanner?,
        assignmentHeading: String,
        assignmentRows: [AssignmentRow],
        emptyAssignmentsMessage: String?,
        quickActions: [Action],
        version: String,
        overflowActions: [Action]
    ) -> [AccessibilityAnnouncement] {
        var announcements: [AccessibilityAnnouncement] = []
        if let recoveryBanner {
            announcements.append(
                AccessibilityAnnouncement(
                    id: "switching-status",
                    label: recoveryBanner.accessibilityLabel,
                    value: recoveryBanner.accessibilityValue,
                    hint: recoveryBanner.detail
                )
            )
            if let action = recoveryBanner.action {
                announcements.append(
                    AccessibilityAnnouncement(
                        id: action.id.rawValue,
                        label: action.accessibilityLabel,
                        value: nil,
                        hint: nil
                    )
                )
            }
        }
        announcements.append(
            AccessibilityAnnouncement(
                id: "assignments-heading",
                label: assignmentHeading,
                value: nil,
                hint: nil
            )
        )
        if let emptyAssignmentsMessage {
            announcements.append(
                AccessibilityAnnouncement(
                    id: "assignments-empty",
                    label: emptyAssignmentsMessage,
                    value: nil,
                    hint: nil
                )
            )
        }
        for row in assignmentRows {
            announcements.append(
                AccessibilityAnnouncement(
                    id: row.id,
                    label: row.accessibilityLabel,
                    value: row.accessibilityValue,
                    hint: row.accessibilityHint
                )
            )
        }
        for action in quickActions {
            announcements.append(
                AccessibilityAnnouncement(
                    id: action.id.rawValue,
                    label: action.accessibilityLabel,
                    value: nil,
                    hint: nil
                )
            )
        }
        announcements.append(
            AccessibilityAnnouncement(
                id: "version",
                label: "Version",
                value: version,
                hint: nil
            )
        )
        announcements.append(
            AccessibilityAnnouncement(
                id: MenuBarPanelActionID.overflow.rawValue,
                label: "More",
                value: nil,
                hint: nil
            )
        )
        for action in overflowActions {
            announcements.append(
                AccessibilityAnnouncement(
                    id: action.id.rawValue,
                    label: action.accessibilityLabel,
                    value: nil,
                    hint: nil
                )
            )
        }
        return announcements
    }

    static func unavailableReasonName(_ reason: SwitchingUnavailableReason) -> String {
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
