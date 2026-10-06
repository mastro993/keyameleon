import AppKit

enum InputMonitoringSettingsWindow {
    case unavailable
    case notRunning
    case noWindow
    case window(CGRect)

    @MainActor
    static func snapshot() -> Self {
        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.systempreferences"
        )
        guard let application = applications.first(where: { !$0.isTerminated }) else {
            return .notRunning
        }
        // Metadata only: no Accessibility or Screen Recording request or capture.
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return .unavailable }

        for window in windows {
            guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
                  owner.int32Value == application.processIdentifier,
                  let layer = window[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0 else { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else {
                return .unavailable
            }
            guard rect.width > 200, rect.height > 200 else { continue }
            return .window(InputMonitoringGuidePlacement.appKitRect(
                from: rect,
                primaryDisplayHeight: CGDisplayBounds(CGMainDisplayID()).height
            ))
        }
        return .noWindow
    }
}
