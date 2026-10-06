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
        NSApp.activate(ignoringOtherApps: true)
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}

@MainActor
protocol SystemSettingsOpening: AnyObject {
    func openSystemSettings()
    func stop()
}

extension SystemSettingsOpening {
    func stop() {}
}

@MainActor
final class NSWorkspaceSystemSettingsOpener: SystemSettingsOpening {
    private let guide: InputMonitoringGuideController
    private let openURL: (URL) -> Bool

    var onPermissionGranted: (() -> Void)? {
        get { guide.onPermissionGranted }
        set { guide.onPermissionGranted = newValue }
    }

    init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider()
    ) {
        guide = InputMonitoringGuideController(permissionProvider: permissionProvider)
        openURL = { NSWorkspace.shared.open($0) }
    }

    init(guide: InputMonitoringGuideController, openURL: @escaping (URL) -> Bool) {
        self.guide = guide
        self.openURL = openURL
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else {
            return
        }

        guard openURL(url) else { return }
        guide.show()
    }

    func stop() {
        guide.stop()
    }
}
