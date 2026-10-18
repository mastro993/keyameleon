#if DEBUG
import Foundation

@MainActor
final class PreviewSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup: Bool
    private(set) var hasCompletedGuidedSetup: Bool
    private(set) var guidedSetupStep: GuidedSetupStep
    private(set) var isActivityTriggeredSwitchingPaused: Bool
    private(set) var hasEvaluatedBuiltInIdentityMigration = true
    private(set) var externalChangeResponse: ExternalChangeResponse = .switchBack

    init(
        hasStartedGuidedSetup: Bool,
        hasCompletedGuidedSetup: Bool,
        guidedSetupStep: GuidedSetupStep,
        isPaused: Bool
    ) {
        self.hasStartedGuidedSetup = hasStartedGuidedSetup
        self.hasCompletedGuidedSetup = hasCompletedGuidedSetup
        self.guidedSetupStep = guidedSetupStep
        isActivityTriggeredSwitchingPaused = isPaused
    }

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasStartedGuidedSetup = true
        hasCompletedGuidedSetup = true
        guidedSetupStep = .ready
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }

    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        externalChangeResponse = response
    }
}

#endif
