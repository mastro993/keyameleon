import Foundation

extension ActivityTriggeredSwitching {
    /// Application lifecycle seam. Not part of the product interface.
    func handleLifecycleEvent(_ event: LifecycleEvent) {
        switch event {
        case .willSleep:
            updateUnavailableReason(.sleeping, isActive: true)
        case .didWake:
            updateUnavailableReason(.sleeping, isActive: false)
        case .sessionDidResignActive:
            updateUnavailableReason(.inactiveSession, isActive: true)
        case .sessionDidBecomeActive:
            updateUnavailableReason(.inactiveSession, isActive: false)
        case .protectedDataWillBecomeUnavailable:
            eventProtectedDataUnavailable = true
            updateUnavailableReason(.protectedDataUnavailable, isActive: true)
        case .protectedDataDidBecomeAvailable:
            eventProtectedDataUnavailable = false
            updateUnavailableReason(.protectedDataUnavailable, isActive: false)
        }

        checkAgain()
    }

    private func updateUnavailableReason(
        _ reason: SwitchingUnavailableReason,
        isActive: Bool
    ) {
        let reasons = SwitchingUnavailableReason.updating(
            outcome.temporarilyUnavailableReasons, reason, isActive: isActive
        )
        guard reasons != outcome.temporarilyUnavailableReasons else {
            return
        }

        outcome = replacingOutcome(reasons: reasons)
    }
}
