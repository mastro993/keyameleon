#if DEBUG
import Foundation

@MainActor
final class PreviewInputSourceProvider: InputSourceProviding {
    func eligibleInputSources() -> [EligibleInputSource] {
        PreviewFixtures.inputSources()
    }
}

#endif
