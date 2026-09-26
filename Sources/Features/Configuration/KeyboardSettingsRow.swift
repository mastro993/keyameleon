import Foundation

/// One row of the Keyboards settings pane, derived once from a Physical Keyboard.
///
/// The row owns the status line, the optional warning and guidance lines, the
/// Input Source control, and which actions the row offers, so the list has a
/// single shape to draw and no branching of its own.
struct KeyboardSettingsRow: Identifiable, Equatable {
    /// What the row's Input Source control says and does.
    enum InputSourceControl: Equatable {
        case assign
        /// A Keyboard Assignment resolves to this Input Source name.
        case change(name: String, localeCode: String?)
        /// A Keyboard Assignment is saved but its Input Source is not available.
        case unavailable

        var title: String {
            switch self {
            case .assign: "Assign Input Source…"
            case let .change(name, _): name
            case .unavailable: "Input Source Unavailable"
            }
        }

        var displayTitle: String {
            switch self {
            case .assign, .unavailable: "--"
            case let .change(_, localeCode): localeCode ?? "--"
            }
        }

        /// True when this control reports a Keyboard Assignment the person must fix.
        var needsAttention: Bool {
            self == .unavailable
        }
    }

    let id: PhysicalKeyboardRecordID
    let name: String
    let isActive: Bool
    /// Connection state, shown for every Physical Keyboard.
    let statusText: String
    /// Why this Physical Keyboard has no Keyboard Assignment, when it cannot have one.
    let warningText: String?
    /// What Manual Physical Keyboard Designation asks of the person, when it is offered.
    let guidanceText: String?
    let inputSourceControl: InputSourceControl?
    let hasAssignment: Bool
    let canRename: Bool
    let canReplace: Bool
    let canForget: Bool
    let canExclude: Bool
    let canStartManualDesignation: Bool

    init(
        physicalKeyboard: PhysicalKeyboard,
        assignedInputSourceName: String?,
        assignedInputSourceLocaleCode: String? = nil,
        canReplace: Bool,
        canForget: Bool,
        canExclude: Bool,
        canStartManualDesignation: Bool
    ) {
        id = physicalKeyboard.id
        name = physicalKeyboard.name
        isActive = physicalKeyboard.isActive
        statusText = Self.connectionText(for: physicalKeyboard)
        canRename = physicalKeyboard.isAssignable && physicalKeyboard.id.isIdentityBased
        self.canReplace = canReplace
        self.canForget = canForget
        self.canExclude = canExclude
        self.canStartManualDesignation = canStartManualDesignation

        switch physicalKeyboard.assignmentState {
        case .unassigned:
            warningText = nil
            guidanceText = nil
            inputSourceControl = .assign
            hasAssignment = false
        case .assigned:
            warningText = nil
            guidanceText = nil
            inputSourceControl = assignedInputSourceName.map {
                InputSourceControl.change(name: $0, localeCode: assignedInputSourceLocaleCode)
            } ?? .unavailable
            hasAssignment = true
        case let .unsupported(reason):
            warningText = Self.unsupportedWarningText(reason)
            guidanceText = canStartManualDesignation
                ? "Save it after it leaves and returns."
                : nil
            inputSourceControl = nil
            hasAssignment = false
        }
    }

    var hasActions: Bool {
        canRename || hasAssignment || canExclude
    }

    /// What a screen reader reads for this row.
    var accessibilityValue: String {
        var parts: [String] = []
        if isActive {
            parts.append("Active")
        }
        parts.append(statusText)
        if let warningText {
            parts.append(warningText)
        }
        if let guidanceText {
            parts.append(guidanceText)
        }
        if let inputSourceControl {
            parts.append(inputSourceControl.title)
        }
        return parts.joined(separator: " · ")
    }

    private static func connectionText(for physicalKeyboard: PhysicalKeyboard) -> String {
        switch physicalKeyboard.connectionState {
        case .disconnected: "Disconnected"
        case .connected: "Connected · \(physicalKeyboard.connectionTypeName)"
        }
    }

    private static func unsupportedWarningText(
        _ reason: PhysicalKeyboardUnsupportedReason
    ) -> String {
        let detail = switch reason {
        case .missingIdentity: "Physical Keyboard Identity unavailable"
        case .unstableIdentity: "Physical Keyboard Identity unstable"
        case .sharedIdentity: "Physical Keyboard Identity shared"
        case .ambiguousIdentity: "Physical Keyboard Identity ambiguous"
        }
        return "Unsupported — \(detail)"
    }
}
