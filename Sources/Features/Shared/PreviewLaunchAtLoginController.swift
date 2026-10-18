#if DEBUG
import Foundation

@MainActor
final class PreviewLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isEnabled: Bool
    private let shouldFail: Bool

    init(isEnabled: Bool, shouldFail: Bool) {
        self.isEnabled = isEnabled
        self.shouldFail = shouldFail
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginChangeError> {
        guard !shouldFail else {
            return .failure(.registrationFailed)
        }
        isEnabled = enabled
        return .success(())
    }
}

#endif
