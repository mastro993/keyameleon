#if DEBUG
import Foundation

@MainActor
final class PreviewPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

#endif
