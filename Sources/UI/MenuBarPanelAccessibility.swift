import Foundation

/// VoiceOver speech and keyboard order for the complete menu-bar panel.
struct MenuBarPanelAccessibility: Equatable, Sendable {
    struct Speech: Equatable, Sendable {
        let label: String
        let value: String?
    }

    enum FocusTarget: Hashable, Sendable {
        case assignment(id: String)
        case openKeyameleon
        case overflow
    }

    let panel: Speech
    let heading: Speech
    let headingIsHeader: Bool
    let items: [Speech]
    let version: Speech
    let openKeyameleon: Speech
    let overflow: Speech
    let overflowActionTitles: [String]
    let keyboardFocusOrder: [FocusTarget]
    let assignmentFocusTitles: [String]

    var voiceOverOrderLabels: [String] {
        [panel.label, heading.label]
            + items.map(\.label)
            + [version.label, openKeyameleon.label, overflow.label]
    }

    var keyboardOperationTitles: [String] {
        assignmentFocusTitles
            + [openKeyameleon.label, overflow.label]
            + overflowActionTitles
    }

    init(content: MenuBarPanelContent) {
        panel = Speech(label: "Keyameleon", value: content.switchingStatus.rawValue)
        heading = Speech(label: content.assignmentList.heading, value: nil)
        headingIsHeader = true
        assignmentFocusTitles = content.assignmentList.rows.map(\.physicalKeyboardName)
        if content.assignmentList.rows.isEmpty {
            items = [
                Speech(
                    label: content.assignmentList.emptyTitle ?? MenuBarAssignmentList.emptyTitle,
                    value: content.assignmentList.emptyDescription
                )
            ]
            keyboardFocusOrder = [.openKeyameleon, .overflow]
        } else {
            items = content.assignmentList.rows.map { row in
                Speech(label: row.accessibilityLabel, value: row.accessibilityValue)
            }
            keyboardFocusOrder =
                content.assignmentList.rows.map { .assignment(id: $0.id) }
                + [.openKeyameleon, .overflow]
        }
        version = Speech(label: "Version", value: content.footer.versionAccessibilityValue)
        openKeyameleon = Speech(label: content.footer.openKeyameleon.title, value: nil)
        overflow = Speech(label: "More", value: nil)
        overflowActionTitles = content.footer.overflowActions.map(\.title)
    }
}

enum MenuBarPanelLayout {
    static let panelWidth: CGFloat = MenuBarPanelContent.panelWidth
    static let nameLineLimit = 2
    static let inputSourceLineLimit = 1
}
