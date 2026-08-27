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
        case openKeyameleon
        case assignment(id: String)
        case action(id: MenuBarPanelActionID)
    }

    let panel: Speech
    let items: [Speech]
    let openKeyameleon: Speech
    let actions: [Speech]
    let keyboardFocusOrder: [FocusTarget]
    let assignmentFocusTitles: [String]

    var voiceOverOrderLabels: [String] {
        [panel.label, openKeyameleon.label]
            + items.map(\.label)
            + actions.map(\.label)
    }

    var keyboardOperationTitles: [String] {
        [openKeyameleon.label]
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
        openKeyameleon = Speech(label: content.footer.openKeyameleon.title, value: nil)
        actions = content.footer.actions.map { action in
            Speech(label: action.title, value: nil)
        }
        keyboardFocusOrder = [.openKeyameleon]
            + content.assignmentList.rows.map { .assignment(id: $0.id) }
            + content.footer.actions
                .filter(\.isEnabled)
                .map { .action(id: $0.id) }
    }
}

enum MenuBarPanelLayout {
    static let panelWidth: CGFloat = MenuBarPanelContent.panelWidth
    static let nameLineLimit = 2
    static let inputSourceLineLimit = 1
}
