#if DEBUG
import Foundation

@MainActor
final class PreviewInputSourceSelector: InputSourceSelecting {
    private(set) var current: String?

    init(current: String?) {
        self.current = current
    }

    func currentInputSourceIdentifier() -> String? {
        current
    }

    func selectAndVerifyInputSource(identifier: String) -> Bool {
        current = identifier
        return true
    }
}

#endif
