import Foundation
import ServiceManagement

enum LaunchAtLoginChangeError: Error, Equatable {
    case registrationFailed
}

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginChangeError>
}

/// Registers the main app via Service Management. No separate login helper.
@MainActor
final class ServiceManagementLaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginChangeError> {
        let service = SMAppService.mainApp

        do {
            if enabled {
                guard service.status != .enabled else {
                    return .success(())
                }
                try service.register()
            } else {
                guard service.status != .notRegistered else {
                    return .success(())
                }
                try service.unregister()
            }
            return .success(())
        } catch {
            return .failure(.registrationFailed)
        }
    }
}
