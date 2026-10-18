import Foundation

enum PhysicalKeyboardTransport: Equatable, Sendable {
    case usb
    case bluetooth
    case bluetoothLowEnergy
    case other
}
