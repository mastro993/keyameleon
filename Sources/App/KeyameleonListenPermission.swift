import AppKit
import IOKit.hid

@MainActor
protocol ListenPermissionProviding: AnyObject {
    func checkListenPermission() -> ListenPermissionState
    func requestListenPermission() -> Bool
}

@MainActor
final class SystemListenPermissionProvider: ListenPermissionProviding {
    func checkListenPermission() -> ListenPermissionState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            .granted
        case kIOHIDAccessTypeDenied:
            .denied
        default:
            .unknown
        }
    }

    func requestListenPermission() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}

@MainActor
protocol SystemSettingsOpening: AnyObject {
    func openSystemSettings()
}

@MainActor
final class NSWorkspaceSystemSettingsOpener: SystemSettingsOpening {
    func openSystemSettings() {
        guard let url = URL(string: KeyameleonAppMetadata.systemSettingsURL) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
