import Foundation

// Internal adapter evidence used by focused module tests. It is not part of
// the product outcome.
extension ActivityTriggeredSwitching {
    var testingActiveWarnings: [SwitchingWarning] {
        activeWarningByCause.values.sorted { $0.id < $1.id }
    }

    var testingWarningEpisodeCount: Int {
        warningEpisodeCount
    }

    var testingVerifiedKeyboardAssignmentIdentifier: String? {
        verifiedKeyboardAssignmentIdentifier
    }

    var testingWantedKeyboardAssignmentIdentifier: String? {
        wantedKeyboardAssignmentIdentifier
    }

    var testingWantedKeyboardAssignmentGeneration: UInt64 {
        wantedKeyboardAssignmentGeneration
    }

    var testingObservedCurrentInputSourceIdentifier: String? {
        observedCurrentInputSourceIdentifier
    }

    var testingWantedKeyboardAssignment: WantedKeyboardAssignment? {
        wantedKeyboardAssignment
    }

    var testingIsStarted: Bool {
        isStarted
    }

    var testingInputSourceHold: InputSourceHold? {
        inputSourceHold.hold
    }
}
