import Foundation

struct StablePhysicalKeyboardFacts: Hashable, Sendable {
    let vendorID: UInt32
    let productID: UInt32
    let modelNumber: String?
    let serialNumber: String?
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
}
