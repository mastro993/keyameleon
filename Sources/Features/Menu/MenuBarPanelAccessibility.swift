import Foundation

/// VoiceOver speech and keyboard order for the complete menu-bar panel.
struct MenuBarPanelAccessibility: Equatable, Sendable {
    struct Speech: Equatable, Sendable {
        let label: String
        let value: String?
    }

    enum FocusTarget: Hashable, Sendable {
        /// Silent initial first responder. No ring until Tab.
        case container
        case about
        case assignment(id: String)
        case action(id: MenuBarPanelActionID)
    }

    let panel: Speech
    let items: [Speech]
    let about: Speech
    let notice: Speech?
    let noticeActionTitle: String?
    let actions: [Speech]
    let keyboardFocusOrder: [FocusTarget]
    let assignmentFocusTitles: [String]

    var voiceOverOrderLabels: [String] {
        [panel.label, about.label]
            + (notice.map { [$0.label] } ?? [])
            + (noticeActionTitle.map { [$0] } ?? [])
            + items.map(\.label)
            + actions.map(\.label)
    }

    var keyboardOperationTitles: [String] {
        [about.label]
            + (noticeActionTitle.map { [$0] } ?? [])
            + assignmentFocusTitles
            + actions.map(\.label)
    }

    init(content: MenuBarPanelContent) {
        panel = Speech(label: "Keyameleon", value: content.switchingStatus.rawValue)
        assignmentFocusTitles = content.assignmentList.rows.map(\.physicalKeyboardName)
        if content.assignmentList.rows.isEmpty {
            items = [
                Speech(
                    label: content.assignmentList.emptyTitle ?? MenuBarAssignmentList.emptyTitle,
                    value: content.assignmentList.emptyDescription
                )
            ]
        } else {
            items = content.assignmentList.rows.map { row in
                Speech(label: row.accessibilityLabel, value: row.accessibilityValue)
            }
        }
        about = Speech(label: content.footer.about.title, value: nil)
        notice = content.notice.map { Speech(label: $0.title, value: $0.detail) }
        noticeActionTitle = content.notice?.action?.title
        actions = content.footer.actions.map { action in
            Speech(label: action.title, value: nil)
        }
        keyboardFocusOrder = [.about]
            + (content.notice?.action.map { [.action(id: $0.id)] } ?? [])
            + content.assignmentList.rows.map { .assignment(id: $0.id) }
            + content.footer.actions
                .filter(\.isEnabled)
                .map { .action(id: $0.id) }
    }
}

enum MenuBarPanelLayout {
    static let panelWidth: CGFloat = MenuBarPanelContent.panelWidth
    static let nameLineLimit = 2
    static let subtitleLineLimit = 1
}
