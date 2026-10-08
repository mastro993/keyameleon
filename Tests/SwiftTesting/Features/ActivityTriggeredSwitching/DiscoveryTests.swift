import CoreHID
import Testing
@testable import Keyameleon

@Test("Stable Physical Keyboard Identity groups matching HID services")
func stablePhysicalKeyboardIdentityGroupsMatchingHIDServices() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeHardwareFacts(serviceID: 11)))
    catalog.apply(.connected(makeHardwareFacts(serviceID: 12)))

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].isAssignable)
    #expect(catalog.physicalKeyboards[0].assignmentState == .unassigned)
}

@Test("Missing Physical Keyboard Identity is unsupported and not assignable")
func missingPhysicalKeyboardIdentityIsUnsupported() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 21,
                identity: nil
            )
        )
    )

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].assignmentState == .unsupported(.missingIdentity))
    #expect(!catalog.physicalKeyboards[0].isAssignable)
}

@Test("Conflicting HID facts make shared Physical Keyboard Identity ambiguous")
func conflictingHIDFactsMakeSharedPhysicalKeyboardIdentityAmbiguous() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeHardwareFacts(serviceID: 31, productID: 100)))
    catalog.apply(.connected(makeHardwareFacts(serviceID: 32, productID: 200)))

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].assignmentState == .unsupported(.ambiguousIdentity))
    #expect(!catalog.physicalKeyboards[0].isAssignable)
}

@Test("Unstable Physical Keyboard Identity is unsupported")
func unstablePhysicalKeyboardIdentityIsUnsupported() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 35,
                serialNumber: nil
            )
        )
    )

    #expect(catalog.physicalKeyboards[0].assignmentState == .unsupported(.unstableIdentity))
    #expect(!catalog.physicalKeyboards[0].isAssignable)
}

@Test("External identity without serial fact is unstable")
func externalIdentityWithoutSerialFactIsUnstable() {
    let facts = makeHardwareFacts(serviceID: 35, serialNumber: nil)

    #expect(facts.identityStability == .unstable)
}

@Test("Bluetooth address without serial is a stable Physical Keyboard Identity")
func bluetoothAddressWithoutSerialIsStablePhysicalKeyboardIdentity() {
    let facts = makeHardwareFacts(
        serviceID: 73,
        serialNumber: nil,
        bluetoothAddress: "fe-f0-58-87-af-5f"
    )

    #expect(facts.identityStability == .stable)
    #expect(facts.identity?.isStable == true)
}

@Test("Matching Bluetooth addresses group HID services as one Physical Keyboard")
func matchingBluetoothAddressesGroupHIDServicesAsOnePhysicalKeyboard() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 74,
                identity: "software-a",
                serialNumber: nil,
                bluetoothAddress: "fe-f0-58-87-af-5f"
            )
        )
    )
    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 75,
                identity: "software-b",
                serialNumber: nil,
                bluetoothAddress: "FE:F0:58:87:AF:5F"
            )
        )
    )

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].isAssignable)
}

@Test("Keyboard usage stays recognized without LED evidence")
func keyboardUsageWithoutLEDIsPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: true,
        hasKeyInputElement: false
    )

    #expect(recognition.isPhysicalKeyboard)
}

@Test("Keyboard input elements identify a Physical Keyboard without advertised keyboard usage")
func keyboardInputElementIdentifiesPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: false,
        hasKeyInputElement: true
    )

    #expect(recognition.isPhysicalKeyboard)
}

@Test("Pointer without keyboard usage or key input stays excluded")
func pointerWithoutKeyboardEvidenceIsNotPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: false,
        hasKeyInputElement: false
    )

    #expect(!recognition.isPhysicalKeyboard)
}

@Test(
    "Keyboard, keypad, and consumer usages identify a Physical Keyboard",
    arguments: [
        HIDUsage.genericDesktop(.keyboard),
        .genericDesktop(.keypad),
        .keyboardOrKeypad(nil),
        .consumer(.consumerControl)
    ]
)
func keyInputUsageIdentifiesPhysicalKeyboard(usage: HIDUsage) {
    #expect(PhysicalKeyboardHIDInspection.isKeyInputUsage(usage))
}

@Test(
    "Usages without key input do not identify a Physical Keyboard",
    arguments: [HIDUsage.genericDesktop(.mouse), .genericDesktop(.pointer)]
)
func usageWithoutKeyInputDoesNotIdentifyPhysicalKeyboard(usage: HIDUsage) {
    #expect(!PhysicalKeyboardHIDInspection.isKeyInputUsage(usage))
}

@Test("Serial-less receiver interfaces group into one assignable Physical Keyboard")
func serialLessReceiverInterfacesGroupIntoOneAssignablePhysicalKeyboard() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeSerialLessFacts(serviceID: 81, uniqueID: "interface-a")))
    catalog.apply(.connected(makeSerialLessFacts(serviceID: 82, uniqueID: "interface-b")))

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].assignmentState == .unassigned)
    #expect(catalog.physicalKeyboards[0].connectedServiceCount == 2)
}

@Test("Serial-less identity survives new CoreHID unique IDs, a missing one, and a new port")
func serialLessIdentityIsIndependentOfUniqueIDAndPort() {
    let original = makeSerialLessFacts(serviceID: 83, uniqueID: "before", locationID: 1)
    let reconnected = makeSerialLessFacts(serviceID: 84, uniqueID: nil, locationID: 2)

    #expect(original.identityStability == .stable)
    #expect(original.identity == reconnected.identity)
}

@Test("Identical serial-less devices on different ports share an unsupported identity")
func identicalSerialLessDevicesOnDifferentPortsAreShared() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeSerialLessFacts(serviceID: 85, uniqueID: "a", locationID: 1)))
    catalog.apply(.connected(makeSerialLessFacts(serviceID: 86, uniqueID: "b", locationID: 2)))

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].assignmentState == .unsupported(.sharedIdentity))
}

@Test(
    "Serial-less device with a zero vendor or product ID stays without identity",
    arguments: [(UInt32(0), UInt32(0)), (0, 1), (0x19F5, 0)]
)
func serialLessDeviceWithZeroVendorOrProductHasNoIdentity(vendorID: UInt32, productID: UInt32) {
    let identity = PhysicalKeyboardIdentity(
        rawValue: nil,
        isBuiltIn: false,
        serialNumber: nil,
        vendorID: vendorID,
        productID: productID
    )

    #expect(identity == nil)
}

@Test("Serial number anchors the identity when CoreHID has no unique ID")
func serialNumberAnchorsIdentityWithoutUniqueID() {
    let first = PhysicalKeyboardIdentity(
        rawValue: nil,
        isBuiltIn: false,
        serialNumber: "keyboard-a",
        vendorID: 0x19F5,
        productID: 0x0001
    )
    let second = PhysicalKeyboardIdentity(
        rawValue: nil,
        isBuiltIn: false,
        serialNumber: "keyboard-b",
        vendorID: 0x19F5,
        productID: 0x0001
    )

    #expect(first?.isStable == true)
    #expect(first?.isModelAnchored == false)
    #expect(first != second)
}

@Test("Different serial facts make a shared Physical Keyboard Identity unsupported")
func differentSerialFactsMakeSharedPhysicalKeyboardIdentityUnsupported() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 36,
                serialNumber: "keyboard-a"
            )
        )
    )
    catalog.apply(
        .connected(
            makeHardwareFacts(
                serviceID: 37,
                serialNumber: "keyboard-b"
            )
        )
    )

    #expect(catalog.physicalKeyboards[0].assignmentState == .unsupported(.sharedIdentity))
    #expect(!catalog.physicalKeyboards[0].isAssignable)
}

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

@Test("Removing last HID service removes Physical Keyboard from catalog")
func removingLastHIDServiceRemovesPhysicalKeyboardFromCatalog() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeHardwareFacts(serviceID: 38)))
    catalog.apply(.disconnected(serviceID: 38))

    #expect(catalog.physicalKeyboards.isEmpty)
}

@Test("Eligible input sources contain enabled selectable keyboard layouts only")
func eligibleInputSourcesContainEnabledSelectableKeyboardLayoutsOnly() {
    let inputSources = EligibleInputSourceCatalog.eligible(
        from: [
            InputSourceFacts(
                identifier: "com.example.us",
                name: "U.S.",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.disabled",
                name: "Disabled",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: false,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.parent-input-method",
                name: "Stateful Input Method",
                category: .keyboard,
                type: .keyboardInputMethodWithModes,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.palette",
                name: "Palette",
                category: .palette,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.custom",
                name: "Custom Layout",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            )
        ]
    )

    #expect(inputSources.map(\.name) == ["Custom Layout", "U.S."])
    #expect(inputSources.allSatisfy { !$0.name.contains("com.example") })
}

@Test("Eligible input source locale code names the layout locale, not its language")
func eligibleInputSourceLocaleCodeNamesLayoutLocale() {
    let inputSources = EligibleInputSourceCatalog.eligible(
        from: [
            InputSourceFacts(
                identifier: "com.apple.keylayout.US",
                name: "U.S.",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: ["en", "it"]
            ),
            InputSourceFacts(
                identifier: "com.apple.keylayout.Italian-Pro",
                name: "Italian",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: ["it"]
            ),
            InputSourceFacts(
                identifier: "com.apple.keylayout.ABC",
                name: "ABC",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: []
            )
        ]
    )

    #expect(inputSources.map(\.localeCode) == [nil, "IT", "US"])
}

@Test("Ready Switching Status starts discovery and publishes configuration choices")
@MainActor
func readySwitchingStatusStartsDiscoveryAndPublishesConfigurationChoices() {
    let permissionProvider = DiscoveryTestListenPermissionProvider(state: .granted)
    let discoverer = TestPhysicalKeyboardDiscoverer()
    let inputSourceProvider = TestInputSourceProvider(
        inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S.")
        ]
    )
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: DiscoveryTestSetupDecisionStore(),
        inputMonitoringRecovery: DiscoveryTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSourceProvider
    )

    startAndCheck(model)
    discoverer.emit(.connected(makeHardwareFacts(serviceID: 41)))

    #expect(discoverer.startCount == 1)
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].assignmentState == .unassigned)
    #expect(model.eligibleInputSources.map { $0.name } == ["U.S."])
}

@Test("Permission Required stops Physical Keyboard discovery")
@MainActor
func permissionRequiredStopsPhysicalKeyboardDiscovery() {
    let permissionProvider = DiscoveryTestListenPermissionProvider(state: .granted)
    let discoverer = TestPhysicalKeyboardDiscoverer()
    let model = SetupModel(
        permissionProvider: permissionProvider,
        setupStore: DiscoveryTestSetupDecisionStore(),
        inputMonitoringRecovery: DiscoveryTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: TestInputSourceProvider(inputSources: [])
    )

    startAndCheck(model)
    permissionProvider.state = .denied
    startAndCheck(model)

    #expect(discoverer.startCount == 1)
    #expect(discoverer.stopCount == 1)
    #expect(model.physicalKeyboards.isEmpty)
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

private func makeHardwareFacts(
    serviceID: UInt64,
    identity: String? = "macos.keyboard.shared",
    productID: UInt32 = 100,
    serialNumber: String? = "keyboard-a",
    bluetoothAddress: String? = nil
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: identity.flatMap {
            PhysicalKeyboardIdentity(
                rawValue: $0,
                isBuiltIn: false,
                serialNumber: serialNumber,
                bluetoothAddress: bluetoothAddress
            )
        },
        name: "Test Keyboard",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 500,
        productID: productID,
        modelNumber: "Model",
        serialNumber: serialNumber
    )
}

private func makeSerialLessFacts(
    serviceID: UInt64,
    uniqueID: String?,
    locationID: UInt64 = 1
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(
            rawValue: uniqueID,
            isBuiltIn: false,
            serialNumber: nil,
            vendorID: 0x19F5,
            productID: 0x0001
        ),
        name: "NuPhy Halo75 V2 Dongle",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 0x19F5,
        productID: 0x0001,
        modelNumber: nil,
        serialNumber: nil,
        locationID: locationID
    )
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

@MainActor
private final class TestPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        startCount += 1
        self.onChange = onChange
    }

    func stop() {
        stopCount += 1
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

@MainActor
private final class TestInputSourceProvider: InputSourceProviding {
    private let inputSources: [EligibleInputSource]

    init(inputSources: [EligibleInputSource]) {
        self.inputSources = inputSources
    }

    func eligibleInputSources() -> [EligibleInputSource] {
        inputSources
    }
}

@MainActor
private final class DiscoveryTestListenPermissionProvider: ListenPermissionProviding {
    var state: ListenPermissionState

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        state
    }

    func requestListenPermission() -> Bool {
        false
    }
}

@MainActor
private final class DiscoveryTestSetupDecisionStore: SetupDecisionStoring {
    var hasStartedGuidedSetup = false
    var hasCompletedGuidedSetup = false
    var guidedSetupStep: GuidedSetupStep = .permission
    var isActivityTriggeredSwitchingPaused = false
    var hasEvaluatedBuiltInIdentityMigration = false

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasCompletedGuidedSetup = true
        guidedSetupStep = .assignments
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }
}

@MainActor
private final class DiscoveryTestInputMonitoringRecovery: InputMonitoringRecovering {
    func openSystemSettings() {}
    func relaunch() {}
    func resetStaleGrantAfterRelaunch() async -> Bool { false }
}
