enum SwitchingStatus: String, Equatable, Sendable {
    case ready = "Ready"
    case permissionRequired = "Permission Required"
    case paused = "Paused"
    case temporarilyUnavailable = "Temporarily Unavailable"

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

enum SwitchingUnavailableReason: Equatable, Hashable, Sendable {
    case sleeping
    case inactiveSession
    case secureInput
    case protectedDataUnavailable
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

/// Typed Physical Keyboard condition that needs user action.
enum PhysicalKeyboardActionCondition: Equatable, Sendable {
    case unassigned(physicalKeyboardName: String)
    case unavailableKeyboardAssignment(physicalKeyboardName: String)
}
