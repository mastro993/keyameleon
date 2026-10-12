import Foundation

// Internal adapter evidence used by focused module tests. It is not part of
// the product outcome.
extension ActivityTriggeredSwitching {
    var testingActiveWarnings: [SwitchingWarning] {
        switchingWarnings.sorted
    }

    var testingWarningEpisodeCount: Int {
        switchingWarnings.episodeCount
    }

    var testingVerifiedInputSourceIdentifier: String? {
        verifiedInputSourceIdentifier
    }

    var testingWantedInputSourceIdentifier: String? {
        wantedInputSourceIdentifier
    }

    var testingWantedInputSourceGeneration: UInt64 {
        wantedInputSourceGeneration
    }

    var testingObservedCurrentInputSourceIdentifier: String? {
        observedCurrentInputSourceIdentifier
    }

    var testingWantedInputSource: WantedInputSource? {
        wantedInputSource
    }

    var testingIsStarted: Bool {
        isStarted
    }

    var testingInputSourceHold: InputSourceHold? {
        inputSourceHold.hold
    }
}
