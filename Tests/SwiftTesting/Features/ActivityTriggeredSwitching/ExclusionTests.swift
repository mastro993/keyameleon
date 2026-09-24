import Foundation
import Testing
@testable import Keyameleon

@Test("Exclusion key of a Physical Keyboard Identity ignores its anchor")
func exclusionKeyIgnoresIdentityAnchor() {
    let serialDevice = makeSetupModelHardwareFacts(
        serviceID: 401,
        identity: "preview.device-a",
        serialNumber: "serial-a"
    )
    let sameDeviceWithoutSerial = makeSetupModelHardwareFacts(
        serviceID: 402,
        identity: "preview.device-a",
        serialNumber: nil
    )
    let savedRecordID = PhysicalKeyboardRecordID(
        rawValue: "identity:preview.device-a|anchor:serial:serial-a"
    )

    #expect(PhysicalKeyboardExclusionKey.key(for: serialDevice) == "identity:preview.device-a")
    #expect(
        PhysicalKeyboardExclusionKey.key(for: sameDeviceWithoutSerial)
            == PhysicalKeyboardExclusionKey.key(for: serialDevice)
    )
    #expect(
        PhysicalKeyboardExclusionKey.key(for: savedRecordID)
            == PhysicalKeyboardExclusionKey.key(for: serialDevice)
    )
}

@Test("Physical Keyboard without Identity keys by its hardware facts")
func physicalKeyboardWithoutIdentityKeysByHardwareFacts() {
    let firstService = makeIdentityLessHardwareFacts(serviceID: 411, vendorID: 200)
    let secondService = makeIdentityLessHardwareFacts(serviceID: 412, vendorID: 200)
    let otherDevice = makeIdentityLessHardwareFacts(serviceID: 413, vendorID: 201)

    #expect(PhysicalKeyboardExclusionKey.key(for: firstService) == "hardware:200:100:Model")
    #expect(
        PhysicalKeyboardExclusionKey.key(for: firstService)
            == PhysicalKeyboardExclusionKey.key(for: secondService)
    )
    #expect(
        PhysicalKeyboardExclusionKey.key(for: firstService)
            != PhysicalKeyboardExclusionKey.key(for: otherDevice)
    )
}

@Test("Built-in Physical Keyboard has no Exclusion key")
func builtInPhysicalKeyboardHasNoExclusionKey() {
    #expect(PhysicalKeyboardExclusionKey.key(for: makeBuiltInHardwareFacts(serviceID: 421)) == nil)
}

@Test("Excluded device leaves the catalog and returns without a reconnect")
func excludedDeviceLeavesCatalogAndReturnsWithoutReconnect() throws {
    var catalog = PhysicalKeyboardCatalog()
    let facts = makeSetupModelHardwareFacts(serviceID: 431)
    let key = try #require(PhysicalKeyboardExclusionKey.key(for: facts))

    catalog.apply(.connected(facts))
    #expect(catalog.physicalKeyboards.count == 1)
    #expect(
        catalog.exclusionKey(
            for: PhysicalKeyboardRecordID(
                rawValue: "identity:macos.keyboard.shared|anchor:serial:keyboard-a"
            )
        ) == key
    )

    catalog.setExcludedKeys([key])
    #expect(catalog.physicalKeyboards.isEmpty)
    #expect(catalog.physicalKeyboard(forServiceID: 431) == nil)

    catalog.setExcludedKeys([])
    #expect(catalog.physicalKeyboards.count == 1)
}

@Test("Built-in Physical Keyboard survives an exclusion key for its identity")
func builtInPhysicalKeyboardSurvivesExclusionKey() {
    var catalog = PhysicalKeyboardCatalog()

    catalog.apply(.connected(makeBuiltInHardwareFacts(serviceID: 441)))
    catalog.setExcludedKeys([
        PhysicalKeyboardExclusionKey.key(for: PhysicalKeyboardRecordID.builtIn)
    ])

    #expect(catalog.physicalKeyboards.count == 1)
    #expect(catalog.physicalKeyboards[0].isBuiltIn)
}

@Test("Excluded device produces no Activation Activity")
@MainActor
func excludedDeviceProducesNoActivationActivity() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let discovery = PhysicalKeyboardDiscovery(
        discoverer: discoverer,
        eventObserver: NoOpPhysicalKeyboardEventObserver()
    )
    let facts = makeSetupModelHardwareFacts(serviceID: 451)
    let key = try #require(PhysicalKeyboardExclusionKey.key(for: facts))
    var activities: [PhysicalKeyboardActivationActivity] = []

    discovery.start()
    discoverer.emit(.connected(facts))
    discovery.startActivationActivityObservation { activities.append($0) }
    discovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 451, kind: .press)
    )
    #expect(activities.count == 1)

    discovery.setExcludedKeys([key])
    discovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 451, kind: .press)
    )
    #expect(activities.count == 1)

    discovery.setExcludedKeys([])
    discovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 451, kind: .press)
    )
    #expect(activities.count == 2)
}

@Test("Restarting discovery keeps saved exclusions")
@MainActor
func restartingDiscoveryKeepsSavedExclusions() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let discovery = PhysicalKeyboardDiscovery(
        discoverer: discoverer,
        eventObserver: NoOpPhysicalKeyboardEventObserver()
    )
    let facts = makeSetupModelHardwareFacts(serviceID: 452)
    let key = try #require(PhysicalKeyboardExclusionKey.key(for: facts))

    discovery.start()
    discoverer.emit(.connected(facts))
    discovery.setExcludedKeys([key])
    #expect(discovery.physicalKeyboards.isEmpty)

    discovery.stop()
    discovery.start()
    discoverer.emit(.connected(facts))

    #expect(discovery.physicalKeyboards.isEmpty)
}

@Test("Excluding a device removes its card and keeps its Keyboard Assignment")
@MainActor
func excludingDeviceRemovesCardAndKeepsKeyboardAssignment() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let model = makeExclusionTestModel(
        discoverer: discoverer,
        exclusionStore: exclusionStore,
        recordStore: recordStore
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 461)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.italian")

    model.excludePhysicalKeyboard(keyboardID)

    #expect(model.physicalKeyboards.isEmpty)
    #expect(model.excludedPhysicalKeyboards.count == 1)
    #expect(model.excludedPhysicalKeyboards[0].name == "Test Keyboard")
    #expect(exclusionStore.allExclusions().map(\.key) == ["identity:macos.keyboard.shared"])

    model.restorePhysicalKeyboard(exclusionKey: try #require(model.excludedPhysicalKeyboards.first).key)

    #expect(model.excludedPhysicalKeyboards.isEmpty)
    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier == "com.example.italian")
}

@Test("Excluded device with a saved record never reappears as disconnected")
@MainActor
func excludedDeviceWithSavedRecordNeverReappearsAsDisconnected() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let exclusionStore = InMemoryPhysicalKeyboardExclusionStore()
    recordStore.saveAssignment(
        identityKey: "identity:macos.keyboard.saved|anchor:serial:keyboard-a",
        productName: "Test Keyboard",
        assignment: KeyboardAssignment(inputSourceIdentifier: "com.example.italian")
    )
    exclusionStore.exclude(
        SavedPhysicalKeyboardExclusion(
            key: "identity:macos.keyboard.saved",
            name: "Logitech USB Receiver"
        )
    )

    let model = makeExclusionTestModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        exclusionStore: exclusionStore,
        recordStore: recordStore
    )

    #expect(model.physicalKeyboards.isEmpty)
    #expect(model.excludedPhysicalKeyboards.count == 1)
}

@Test("Disconnected Physical Keyboard with a saved record stays excludable")
@MainActor
func disconnectedPhysicalKeyboardStaysExcludable() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    recordStore.saveName(
        identityKey: "identity:preview.mouse|anchor:serial:mouse-1",
        productName: "MX Master 2S",
        customName: nil
    )
    let model = makeExclusionTestModel(
        discoverer: SetupModelTestPhysicalKeyboardDiscoverer(),
        recordStore: recordStore
    )
    let mouse = try #require(model.physicalKeyboards.first)

    #expect(mouse.connectionState == .disconnected)
    #expect(model.canExcludePhysicalKeyboard(mouse.id))

    model.excludePhysicalKeyboard(mouse.id)

    #expect(model.physicalKeyboards.isEmpty)
    #expect(
        model.excludedPhysicalKeyboards == [
            SavedPhysicalKeyboardExclusion(key: "identity:preview.mouse", name: "MX Master 2S")
        ]
    )
}

@Test("Built-in Physical Keyboard cannot be excluded")
@MainActor
func builtInPhysicalKeyboardCannotBeExcluded() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeExclusionTestModel(discoverer: discoverer)
    startAndCheck(model)
    discoverer.emit(.connected(makeBuiltInHardwareFacts(serviceID: 471)))
    let builtInID = model.physicalKeyboards[0].id

    #expect(model.physicalKeyboards[0].isBuiltIn)
    #expect(!model.canExcludePhysicalKeyboard(builtInID))

    model.excludePhysicalKeyboard(builtInID)

    #expect(model.excludedPhysicalKeyboards.isEmpty)
    #expect(model.physicalKeyboards.count == 1)
}

@Test("Excluding a device cancels its wanted Keyboard Assignment")
@MainActor
func excludingDeviceCancelsWantedKeyboardAssignment() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.other", verifySuccess: false)
    let model = makeExclusionTestModel(
        discoverer: discoverer,
        inputSources: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.other", name: "Other")
            ]
        ),
        selector: selector
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 481)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery
        .handlePhysicalKeyboardEventForTesting(PhysicalKeyboardEvent(serviceID: 481, kind: .press))

    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment != nil)
    #expect(model.activityTriggeredSwitching.outcome.availableActions.contains(.retryNow))

    model.excludePhysicalKeyboard(keyboardID)

    #expect(model.activityTriggeredSwitching.testingWantedKeyboardAssignment == nil)
    #expect(!model.activityTriggeredSwitching.outcome.availableActions.contains(.retryNow))
    #expect(model.activityTriggeredSwitching.testingActiveWarnings.isEmpty)
}

@Test("Excluded device keeps no Unavailable Keyboard Assignment warning")
@MainActor
func excludedDeviceKeepsNoUnavailableKeyboardAssignmentWarning() {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = makeExclusionTestModel(
        discoverer: discoverer,
        inputSources: SetupModelTestInputSourceProvider(
            inputSources: [EligibleInputSource(identifier: "com.example.us", name: "U.S.")]
        )
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 491)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.missing")

    #expect(
        model.activityTriggeredSwitching.testingActiveWarnings.contains {
            $0.cause == .unavailableKeyboardAssignment(keyboardID)
        }
    )

    model.excludePhysicalKeyboard(keyboardID)

    #expect(
        !model.activityTriggeredSwitching.testingActiveWarnings.contains {
            $0.cause == .unavailableKeyboardAssignment(keyboardID)
        }
    )
}

@Test("Exclusion survives a store re-read and stays one row")
@MainActor
func exclusionSurvivesStoreReread() {
    let suiteName = "dev.fedemas.keyameleon.tests.exclusion.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsPhysicalKeyboardExclusionStore(defaults: defaults)
    #expect(store.allExclusions().isEmpty)

    let exclusion = SavedPhysicalKeyboardExclusion(
        key: "hardware:200:100:Model",
        name: "Logitech USB Receiver"
    )
    store.exclude(exclusion)
    store.exclude(exclusion)

    let reloaded = UserDefaultsPhysicalKeyboardExclusionStore(defaults: defaults)
    #expect(reloaded.allExclusions() == [exclusion])

    reloaded.restore(key: exclusion.key)
    #expect(UserDefaultsPhysicalKeyboardExclusionStore(defaults: defaults).allExclusions().isEmpty)
}

@MainActor
private func makeExclusionTestModel(
    discoverer: SetupModelTestPhysicalKeyboardDiscoverer,
    exclusionStore: any PhysicalKeyboardExclusionStoring = InMemoryPhysicalKeyboardExclusionStore(),
    recordStore: InMemoryPhysicalKeyboardRecordStore = InMemoryPhysicalKeyboardRecordStore(),
    inputSources: SetupModelTestInputSourceProvider = SetupModelTestInputSourceProvider(
        inputSources: []
    ),
    selector: SetupModelTestInputSourceSelector = SetupModelTestInputSourceSelector(
        current: nil,
        verifySuccess: true
    )
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: inputSources,
        inputSourceSelector: selector,
        physicalKeyboardRecordStore: recordStore,
        exclusionStore: exclusionStore
    )
}

private func makeIdentityLessHardwareFacts(
    serviceID: UInt64,
    vendorID: UInt32
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: nil,
        name: "Logitech USB Receiver",
        transport: .usb,
        isBuiltIn: false,
        vendorID: vendorID,
        productID: 100,
        modelNumber: "Model",
        serialNumber: nil
    )
}

private func makeBuiltInHardwareFacts(serviceID: UInt64) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(
            rawValue: "macos.keyboard.built-in",
            isBuiltIn: true,
            serialNumber: nil
        ),
        name: "Apple Internal Keyboard",
        transport: .usb,
        isBuiltIn: true,
        vendorID: 500,
        productID: 100,
        modelNumber: "Model",
        serialNumber: nil
    )
}
