import Foundation

struct PhysicalKeyboardHardwareFacts: Equatable, Sendable {
    let serviceID: UInt64
    let identity: PhysicalKeyboardIdentity?
    let identityStability: PhysicalKeyboardIdentityStability
    let name: String?
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
    let vendorID: UInt32
    let productID: UInt32
    let modelNumber: String?
    let serialNumber: String?
    /// Port path; every HID interface of one USB device shares it.
    let locationID: UInt64?

    init(
        serviceID: UInt64,
        identity: PhysicalKeyboardIdentity?,
        name: String?,
        transport: PhysicalKeyboardTransport,
        isBuiltIn: Bool,
        vendorID: UInt32,
        productID: UInt32,
        modelNumber: String?,
        serialNumber: String?,
        locationID: UInt64? = nil
    ) {
        self.serviceID = serviceID
        self.identity = identity
        self.identityStability = identity?.isStable == true ? .stable : .unstable
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.transport = transport
        self.isBuiltIn = isBuiltIn
        self.vendorID = vendorID
        self.productID = productID
        self.modelNumber = modelNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.serialNumber = serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.locationID = locationID
    }

    var stableFacts: StablePhysicalKeyboardFacts {
        StablePhysicalKeyboardFacts(
            vendorID: vendorID,
            productID: productID,
            modelNumber: modelNumber,
            serialNumber: serialNumber,
            transport: transport,
            isBuiltIn: isBuiltIn
        )
    }

}
