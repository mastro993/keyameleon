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

    /// Shows the macOS consent alert and adds Keyameleon to the Input
    /// Monitoring list, switched off. Only an unknown decision prompts; once a
    /// row exists, macOS answers without showing anything.
    func requestListenPermission() -> Bool {
        NSApp.activate()
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}
