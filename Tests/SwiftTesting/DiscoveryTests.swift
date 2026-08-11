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
    serialNumber: String? = "keyboard-a"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: identity.flatMap {
            PhysicalKeyboardIdentity(
                rawValue: $0,
                isBuiltIn: false,
                serialNumber: serialNumber
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
}

@MainActor
private final class DiscoveryTestSystemSettingsOpener: SystemSettingsOpening {
    func openSystemSettings() {}
}
