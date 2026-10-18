import Foundation

@MainActor
final class UserDefaultsSetupDecisionStore: SetupDecisionStoring {
    private enum Key {
        static let hasStartedGuidedSetup = "keyameleon.guidedSetup.started"
        static let hasCompletedGuidedSetup = "keyameleon.guidedSetup.completed"
        static let guidedSetupStep = "keyameleon.guidedSetup.step"
        static let isActivityTriggeredSwitchingPaused =
            "keyameleon.activityTriggeredSwitching.paused"
        static let hasEvaluatedBuiltInIdentityMigration =
            "keyameleon.builtInIdentityMigration.evaluated"
        static let externalChangeResponse =
            "keyameleon.activityTriggeredSwitching.externalChangeResponse"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasStartedGuidedSetup: Bool {
        defaults.bool(forKey: Key.hasStartedGuidedSetup)
    }

    var hasCompletedGuidedSetup: Bool {
        defaults.bool(forKey: Key.hasCompletedGuidedSetup)
    }

    var guidedSetupStep: GuidedSetupStep {
        guard
            let rawValue = defaults.string(forKey: Key.guidedSetupStep),
            let step = GuidedSetupStep(rawValue: rawValue)
        else {
            return .permission
        }

        return step
    }

    var isActivityTriggeredSwitchingPaused: Bool {
        defaults.bool(forKey: Key.isActivityTriggeredSwitchingPaused)
    }

    var hasEvaluatedBuiltInIdentityMigration: Bool {
        defaults.bool(forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }

    var externalChangeResponse: ExternalChangeResponse {
        defaults.string(forKey: Key.externalChangeResponse)
            .flatMap(ExternalChangeResponse.init(rawValue:)) ?? .switchBack
    }

    func markGuidedSetupStarted() {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        if defaults.string(forKey: Key.guidedSetupStep) == nil {
            defaults.set(GuidedSetupStep.permission.rawValue, forKey: Key.guidedSetupStep)
        }
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        defaults.set(step.rawValue, forKey: Key.guidedSetupStep)
    }

    func markGuidedSetupCompleted() {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        defaults.set(true, forKey: Key.hasCompletedGuidedSetup)
        defaults.set(GuidedSetupStep.ready.rawValue, forKey: Key.guidedSetupStep)
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        defaults.set(paused, forKey: Key.isActivityTriggeredSwitchingPaused)
    }

    func markBuiltInIdentityMigrationEvaluated() {
        defaults.set(true, forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }

    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        defaults.set(response.rawValue, forKey: Key.externalChangeResponse)
    }
}
