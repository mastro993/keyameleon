@MainActor
protocol SetupDecisionStoring: AnyObject {
    var hasStartedGuidedSetup: Bool { get }
    var hasCompletedGuidedSetup: Bool { get }
    var guidedSetupStep: GuidedSetupStep { get }
    var isActivityTriggeredSwitchingPaused: Bool { get }
    var hasEvaluatedBuiltInIdentityMigration: Bool { get }
    var externalChangeResponse: ExternalChangeResponse { get }

    func markGuidedSetupStarted()
    func markGuidedSetupStep(_ step: GuidedSetupStep)
    func markGuidedSetupCompleted()
    func setActivityTriggeredSwitchingPaused(_ paused: Bool)
    func markBuiltInIdentityMigrationEvaluated()
    func setExternalChangeResponse(_ response: ExternalChangeResponse)
}
