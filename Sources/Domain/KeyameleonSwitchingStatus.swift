enum SwitchingStatus: String, Equatable {
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
}

enum ListenPermissionState: Equatable {
    case granted
    case denied
    case unknown

    var switchingStatus: SwitchingStatus {
        self == .granted ? .ready : .permissionRequired
    }
}
