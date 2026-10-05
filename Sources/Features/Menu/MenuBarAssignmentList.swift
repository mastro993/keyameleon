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
        let subtitle: String
        let assignedInputSourceName: String
        /// Locale code of the assigned Input Source, such as `US` or `IT`.
        /// `nil` when the Input Source is unavailable or reports no language.
        let assignedLocaleCode: String?
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
        assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource]
    ) {
        heading = Self.heading

        let assigned = physicalKeyboards.filter { $0.keyboardAssignment != nil }
        let ordered = PhysicalKeyboardListOrdering.sorted(assigned)
        rows = ordered.map { physicalKeyboard in
            let savedSource = assignedInputSources[physicalKeyboard.id]
            let isUnavailable = savedSource == nil
            let connectionMark = Self.connectionMark(for: physicalKeyboard)
            let state = physicalKeyboard.isBuiltIn && connectionMark != .disconnected
                ? "Built-in" : connectionMark.accessibilityName
            return Row(
                id: physicalKeyboard.id.rawValue,
                physicalKeyboardName: physicalKeyboard.name,
                subtitle: physicalKeyboard.customName == nil
                    ? state
                    : "\(physicalKeyboard.productName) - \(state)",
                assignedInputSourceName: savedSource?.name ?? Self.unavailableInputSourceName,
                assignedLocaleCode: savedSource?.localeCode,
                connectionMark: connectionMark,
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
