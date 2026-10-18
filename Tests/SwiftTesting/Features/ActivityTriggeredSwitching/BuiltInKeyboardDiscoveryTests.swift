import Testing
@testable import Keyameleon

@Test("Built-in HID services use one fixed assignable Physical Keyboard Identity")
func builtInHIDServicesUseOneFixedAssignablePhysicalKeyboardIdentity() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 61,
                identity: "macos.keyboard.first",
                name: "Apple Internal Keyboard",
                transport: .usb,
                productID: 100
            )
        )
    )
    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 62,
                identity: nil,
                name: "Other Internal Interface",
                transport: .bluetooth,
                productID: 200,
                modelNumber: "Different Model"
            )
        )
    )

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].id.rawValue == "identity:built-in|anchor:built-in")
    #expect(catalog.physicalKeyboards[0].isBuiltIn)
    #expect(catalog.physicalKeyboards[0].isAssignable)
    #expect(catalog.physicalKeyboards[0].connectedServiceCount == 2)
    #expect(catalog.physicalKeyboards[0].name == "Built-in Keyboard")
}

@Test("Built-in HID services keep one shared product name when all names match")
func builtInHIDServicesKeepOneSharedProductNameWhenAllNamesMatch() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 63,
                identity: "macos.keyboard.first",
                name: "Apple Internal Keyboard"
            )
        )
    )
    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 64,
                identity: "macos.keyboard.second",
                name: "Apple Internal Keyboard"
            )
        )
    )

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].name == "Apple Internal Keyboard")
}

@Test("Built-in HID services use fallback name when one product name is missing")
func builtInHIDServicesUseFallbackNameWhenOneProductNameIsMissing() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 65,
                identity: "macos.keyboard.first",
                name: "Apple Internal Keyboard"
            )
        )
    )
    catalog.apply(
        .connected(
            makeBuiltInHardwareFacts(
                serviceID: 66,
                identity: "macos.keyboard.second",
                name: nil
            )
        )
    )

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].name == "Built-in Keyboard")
}

@Test("The built-in keyboard is always first")
func builtInKeyboardIsAlwaysFirst() {
    let external = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:external|anchor:serial:external"),
        productName: "External Keyboard",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unassigned,
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
    let builtIn = PhysicalKeyboard(
        id: .builtIn,
        productName: "MacBook Keyboard",
        customName: nil,
        transport: .other,
        isBuiltIn: true,
        assignmentState: .unassigned,
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )

    let ordered = PhysicalKeyboardListOrdering.sorted([external, builtIn])

    #expect(ordered.map(\.id) == [builtIn.id, external.id])
}

@Test("A saved built-in keyboard remains connected")
func savedBuiltInKeyboardRemainsConnected() {
    let record = SavedPhysicalKeyboardRecord(
        identityKey: PhysicalKeyboardRecordID.builtIn.rawValue,
        productName: "MacBook Keyboard"
    )

    let restored = PhysicalKeyboard.restored(from: record)

    #expect(restored.isBuiltIn)
    #expect(restored.connectionState == .connected)
    #expect(restored.connectedServiceCount == 1)
}

private func makeBuiltInHardwareFacts(
    serviceID: UInt64,
    identity: String?,
    name: String?,
    transport: PhysicalKeyboardTransport = .usb,
    productID: UInt32 = 100,
    modelNumber: String = "Model"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: identity.flatMap {
            PhysicalKeyboardIdentity(
                rawValue: $0,
                isBuiltIn: true,
                serialNumber: nil
            )
        },
        name: name,
        transport: transport,
        isBuiltIn: true,
        vendorID: 500,
        productID: productID,
        modelNumber: modelNumber,
        serialNumber: nil
    )
}
