#if DEBUG
import Foundation

@MainActor
final class PreviewProtectedStateProvider: ProtectedStateProviding {
    func currentProtectedState() -> ProtectedStateSnapshot {
        .clear
    }
}

#endif
