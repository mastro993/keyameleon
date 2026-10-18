#if DEBUG
import Foundation

@MainActor
final class PreviewListenPermissionProvider: ListenPermissionProviding {
    private(set) var state: ListenPermissionState

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        state
    }

    func requestListenPermission() -> Bool {
        state = .granted
        return true
    }
}

#endif
