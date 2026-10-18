import Foundation

extension ActivityTriggeredSwitching {
    /// Actions depend on the Input Monitoring decision, not only on status:
    /// an unknown decision is requested, a denied one is fixed in Settings.
    func availableActions(
        warnings: [ActivityTriggeredSwitchingWarning]
    ) -> Set<ActivityTriggeredSwitchingAction> {
        ActivityTriggeredSwitchingAction.available(
            for: outcome.switchingStatus,
            listenPermission: lastKnownListenPermission,
            warnings: warnings,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    func replacingOutcome(
        status: SwitchingStatus? = nil,
        reasons: [SwitchingUnavailableReason]? = nil
    ) -> ActivityTriggeredSwitchingOutcome {
        outcome.replacing(
            status: status,
            reasons: reasons,
            listenPermission: lastKnownListenPermission,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    /// Polls permission only while it is missing, and refreshes the outcome
    /// when the decision changes (alert answered, or grant applied).
    func updatePermissionWatch(for status: SwitchingStatus) {
        guard isStarted, status == .permissionRequired else {
            return permissionWatch.stop()
        }
        permissionWatch.start { [weak self] in
            guard let self, permissionProvider.checkListenPermission() != lastKnownListenPermission else { return }
            checkAgain()
        }
    }
}
