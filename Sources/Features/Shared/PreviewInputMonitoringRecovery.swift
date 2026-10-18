#if DEBUG
import Foundation

@MainActor
final class PreviewInputMonitoringRecovery: InputMonitoringRecovering {
    func openSystemSettings() {}
    func relaunch() {}
    func resetStaleGrantAfterRelaunch() async -> Bool { false }
}

#endif
