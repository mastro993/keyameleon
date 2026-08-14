import Foundation

/// Assigned-only filter/order seam for the menu-bar panel. Actions stay out.
struct MenuBarAssignmentList: Equatable, Sendable {
    static let heading = "Keyboards"
    static let emptyTitle = "No assigned keyboards"
    static let emptyDescription = "Open Keyameleon Settings to assign keyboards."
    static let unavailableInputSourceName = "Unavailable Input Source"
    static let unavailableNote = "Unavailable Keyboard Assignment"
    /// Visible pill viewport. The list itself is unbounded.
    static let visibleRowLimit = 5

    enum ConnectionMark: Equatable, Sendable {
        case active
        case connected
        case disconnected

        var accessibilityName: String {
            switch self {
            case .active:
                "Active"
            case .connected:
                "Connected"
            case .disconnected:
                "Disconnected"
            }
        }
    }

    struct Row: Equatable, Identifiable, Sendable {
        let id: String
        let physicalKeyboardName: String
        let assignedInputSourceName: String
        let connectionMark: ConnectionMark
        let isDimmed: Bool
        let warningNote: String?
        let showsWarningSymbol: Bool

        var accessibilityMark: String {
            connectionMark.accessibilityName
        }

        var accessibilityLabel: String {
            physicalKeyboardName
        }

        var accessibilityValue: String {
            [assignedInputSourceName, accessibilityMark, warningNote]
                .compactMap { $0 }
                .joined(separator: ", ")
        }

        var isActive: Bool {
            connectionMark == .active
        }
    }

    let heading: String
    let rows: [Row]
    let emptyTitle: String?
    let emptyDescription: String?

    var scrolls: Bool {
        rows.count > Self.visibleRowLimit
    }

    init(
        physicalKeyboards: [PhysicalKeyboard],
        assignedInputSourceNames: [PhysicalKeyboardRecordID: String]
    ) {
        heading = Self.heading

        let assigned = physicalKeyboards.filter { $0.keyboardAssignment != nil }
        let activeID = assigned.first(where: \.isActive)?.id
        let ordered = PhysicalKeyboardListOrdering.sorted(assigned, activeID: activeID)
        rows = ordered.map { physicalKeyboard in
            let savedName = assignedInputSourceNames[physicalKeyboard.id]
            let isUnavailable = savedName == nil
            return Row(
                id: physicalKeyboard.id.rawValue,
                physicalKeyboardName: physicalKeyboard.name,
                assignedInputSourceName: savedName ?? Self.unavailableInputSourceName,
                connectionMark: Self.connectionMark(for: physicalKeyboard),
                isDimmed: physicalKeyboard.connectionState == .disconnected,
                warningNote: isUnavailable ? Self.unavailableNote : nil,
                showsWarningSymbol: isUnavailable
            )
        }
        emptyTitle = rows.isEmpty ? Self.emptyTitle : nil
        emptyDescription = rows.isEmpty ? Self.emptyDescription : nil
    }

    private static func connectionMark(for physicalKeyboard: PhysicalKeyboard) -> ConnectionMark {
        if physicalKeyboard.isActive {
            return .active
        }

        switch physicalKeyboard.connectionState {
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        }
    }
}
