import Foundation

enum PhysicalKeyboardDiscoveryChange: Sendable {
    case connected(PhysicalKeyboardHardwareFacts)
    case disconnected(serviceID: UInt64)
}
