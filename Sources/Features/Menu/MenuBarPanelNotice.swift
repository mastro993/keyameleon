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
        physicalKeyboards: [PhysicalKeyboard]
    ) -> MenuBarPanelNotice? {
        switch outcome.switchingStatus {
        case .permissionRequired:
            return permissionNotice(outcome: outcome)
        case .temporarilyUnavailable:
            let reasons = outcome.temporarilyUnavailableReasons
            let detail: LocalizedStringResource = if reasons.contains(.sleeping) {
                .switchingResumesSleeping
            } else if reasons.contains(.inactiveSession) {
                .switchingResumesLocked
            } else if reasons.contains(.secureInput) {
                .switchingResumesSecureInput
            } else if reasons.contains(.protectedDataUnavailable) {
                .switchingResumesProtectedData
            } else {
                .switchingResumes
            }
            return MenuBarPanelNotice(
                title: String(localized: .switchingUnavailable),
                detail: String(localized: detail),
                action: settingsAction,
                tone: .neutral
            )
        case .paused:
            return nil
        case .ready:
            if let warning = outcome.warnings.first(where: { $0.category == .selectionFailed }) {
                let canRetry = outcome.hasAction(.retryNow)
                let detail: LocalizedStringResource = warning.physicalKeyboardName.map {
                    canRetry ? .selectionFailedRetryKeyboard($0) : .selectionFailedCheckKeyboard($0)
                } ?? (canRetry ? .selectionFailedRetry : .selectionFailedCheck)
                return MenuBarPanelNotice(
                    title: String(localized: .selectionFailed),
                    detail: String(localized: detail),
                    action: canRetry
                        ? MenuBarPanelContent.Action(
                            id: .retryNow,
                            title: String(localized: .retryNow),
                            isEnabled: true
                        )
                        : settingsAction,
                    tone: .neutral
                )
            }

            if let hold = outcome.inputSourceHold {
                return holdNotice(hold, inputSourceName: outcome.currentInputSourceName)
            }

            if let mismatch = outcome.mismatch {
                let detail: LocalizedStringResource = if let appName = mismatch.appName {
                    .inputSourceDiffersApp(appName, mismatch.currentName, mismatch.assignedName)
                } else if let keyboardName = outcome.activePhysicalKeyboard?.name {
                    .inputSourceDiffersKeyboard(keyboardName, mismatch.currentName, mismatch.assignedName)
                } else {
                    .inputSourceDiffersNoKeyboard(mismatch.currentName, mismatch.assignedName)
                }
                return MenuBarPanelNotice(
                    title: String(localized: .inputSourceDiffers),
                    detail: sentence(String(localized: detail)),
                    action: settingsAction,
                    tone: .neutral
                )
            }

            let unassignedNames = physicalKeyboards
                .filter { $0.assignmentState == .unassigned }
                .map(\.name)
            if let firstName = unassignedNames.first {
                let detail: LocalizedStringResource = switch unassignedNames.count {
                case 1: .chooseInputSourceForOne(firstName)
                case 2: .chooseInputSourcesForTwo(firstName, unassignedNames[1])
                default: .chooseInputSourcesForMany(unassignedNames.count)
                }
                return MenuBarPanelNotice(
                    title: String(localized: unassignedNames.count == 1 ? .keyboardNotAssigned : .keyboardsNotAssigned),
                    detail: String(localized: detail),
                    action: settingsAction,
                    tone: .neutral
                )
            }
            return nil
        }
    }

    /// An Input Source Hold keeps the current Input Source until its end rule
    /// is met; Switch Back Now ends it early.
    private static func holdNotice(
        _ hold: ExternalChangeResponse,
        inputSourceName: String?
    ) -> MenuBarPanelNotice {
        let detail: LocalizedStringResource = switch (hold, inputSourceName) {
        case let (.holdUntilMatch, name?): .holdUntilMatch(name)
        case (.holdUntilMatch, nil): .holdUntilMatchUnnamed
        case let (.holdUntilKeyboardChange, name?), let (.switchBack, name?): .holdUntilKeyboardChange(name)
        case (.holdUntilKeyboardChange, nil), (.switchBack, nil): .holdUntilKeyboardChangeUnnamed
        }
        return MenuBarPanelNotice(
            title: String(localized: .inputSourceKept),
            detail: String(localized: detail),
            action: .init(id: .switchBackNow, title: String(localized: .switchBackNow), isEnabled: true),
            tone: .neutral
        )
    }

    /// Never asked: the macOS alert lists Keyameleon. Asked before: the
    /// person turns it on in System Settings; Restart sits in the commands.
    private static func permissionNotice(outcome: ActivityTriggeredSwitchingOutcome) -> MenuBarPanelNotice {
        let name = AppIdentity.current.name
        if outcome.hasAction(.openSystemSettings) {
            return MenuBarPanelNotice(
                title: String(localized: .inputMonitoringOff),
                detail: String(localized: .inputMonitoringOffDetail(name, name)),
                action: .init(id: .openSystemSettings, title: String(localized: .openSystemSettings), isEnabled: true),
                tone: .warning
            )
        }
        return MenuBarPanelNotice(
            title: String(localized: .inputMonitoringRequired),
            detail: String(localized: .inputMonitoringRequiredDetail(name)),
            action: outcome.hasAction(.requestPermission)
                ? .init(
                    id: .requestPermission,
                    title: String(localized: .allowInputMonitoringEllipsis),
                    isEnabled: true
                )
                : settingsAction,
            tone: .warning
        )
    }

    private static var settingsAction: MenuBarPanelContent.Action {
        .init(id: .settings, title: String(localized: .openSettings), isEnabled: true)
    }

    /// An Input Source name such as `U.S.` already ends the sentence, so its
    /// period is not doubled.
    private static func sentence(_ text: String) -> String {
        text.hasSuffix("..") ? String(text.dropLast()) : text
    }
}
