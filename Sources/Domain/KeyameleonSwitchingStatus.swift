enum SwitchingStatus: String, Equatable, Sendable {
    case ready = "Ready"
    case permissionRequired = "Permission Required"
    case paused = "Paused"
    case temporarilyUnavailable = "Temporarily Unavailable"

    var displayName: String {
        rawValue
    }

    var allowsActivityTriggeredSwitching: Bool {
        self == .ready
    }

    /// Discovery supports management while Ready or Paused. Key Content observation stays Ready-only.
    var allowsPhysicalKeyboardDiscovery: Bool {
        switch self {
        case .ready, .paused:
            true
        case .permissionRequired, .temporarilyUnavailable:
            false
        }
    }

    /// Priority: Permission Required, Temporarily Unavailable, Paused, Ready.
    static func resolve(
        listenPermission: ListenPermissionState,
        isTemporarilyUnavailable: Bool,
        isPaused: Bool
    ) -> SwitchingStatus {
        if listenPermission != .granted {
            return .permissionRequired
        }

        if isTemporarilyUnavailable {
            return .temporarilyUnavailable
        }

        if isPaused {
            return .paused
        }

        return .ready
    }
}

enum ListenPermissionState: Equatable, Sendable {
    case granted
    case denied
    case unknown

    var switchingStatus: SwitchingStatus {
        SwitchingStatus.resolve(
            listenPermission: self,
            isTemporarilyUnavailable: false,
            isPaused: false
        )
    }
}

/// Menu bar icon mark. Distinct shapes; must not rely on color alone.
enum MenuBarIconMark: Equatable, Sendable {
    case ready
    case permissionRequired
    case temporarilyUnavailable
    case paused
    case warning

    var systemSymbolName: String {
        switch self {
        case .ready:
            "keyboard"
        case .permissionRequired:
            // Distinct shape from ready keyboard; available on macOS 15 SF Symbols.
            "keyboard.badge.ellipsis"
        case .temporarilyUnavailable:
            "moon.zzz"
        case .paused:
            "pause.circle"
        case .warning:
            "exclamationmark.triangle"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .ready:
            KeyameleonAppMetadata.displayName
        case .permissionRequired:
            "Keyameleon — Permission Required"
        case .temporarilyUnavailable:
            "Keyameleon — Temporarily Unavailable"
        case .paused:
            "Keyameleon — Paused"
        case .warning:
            "Keyameleon — Action needed"
        }
    }

    /// Global Switching Status first; item conditions only when Ready.
    static func resolve(
        switchingStatus: SwitchingStatus,
        hasItemConditionsNeedingAction: Bool
    ) -> MenuBarIconMark {
        switch switchingStatus {
        case .permissionRequired:
            .permissionRequired
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        case .paused:
            .paused
        case .ready:
            hasItemConditionsNeedingAction ? .warning : .ready
        }
    }
}

/// Compact Menu first lines for records that need user action.
enum MenuFirstActionItem: Equatable, Sendable {
    case unassigned(physicalKeyboardName: String)
    case unavailableKeyboardAssignment(physicalKeyboardName: String)

    var menuTitle: String {
        switch self {
        case let .unassigned(name):
            "\(KeyameleonAppMetadata.needsActionMenuItemPrefix) \(name) — Unassigned"
        case let .unavailableKeyboardAssignment(name):
            "\(KeyameleonAppMetadata.needsActionMenuItemPrefix) \(name) — Unavailable Keyboard Assignment"
        }
    }
}
