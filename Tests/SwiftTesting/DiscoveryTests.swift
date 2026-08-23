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

@Test("Pointer HID with keyboard usage and no LED is not a Physical Keyboard")
func pointerHIDWithKeyboardUsageAndNoLEDIsNotPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyboardUsage: true,
        hasMouseUsage: true,
        hasKeyboardLED: false
    )

    #expect(!recognition.isPhysicalKeyboard)
}

@Test("Keyboard HID with pointing collection and LED is a Physical Keyboard")
func keyboardHIDWithPointingCollectionAndLEDIsPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyboardUsage: true,
        hasMouseUsage: true,
        hasKeyboardLED: true
    )

    #expect(recognition.isPhysicalKeyboard)
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
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: DiscoveryTestSetupDecisionStore(),
        systemSettingsOpener: DiscoveryTestSystemSettingsOpener(),
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
    let model = KeyameleonSetupModel(
        permissionProvider: permissionProvider,
        setupStore: DiscoveryTestSetupDecisionStore(),
        systemSettingsOpener: DiscoveryTestSystemSettingsOpener(),
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
private final class DiscoveryTestSystemSettingsOpener: SystemSettingsOpening {
    func openSystemSettings() {}
}
