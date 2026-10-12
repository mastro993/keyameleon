import CryptoKit
import Foundation
import Testing
@testable import Keyameleon

// MARK: - Evidence

@Test("CryptoKit authenticates Manual Physical Keyboard Designation evidence")
func cryptoKitAuthenticatesManualDesignationEvidence() {
    let key = SymmetricKey(size: .bits256)
    let tag = ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
        identityKey: "identity:macos.keyboard.a|anchor:serial:s1",
        productName: "Board",
        confirmedName: "Travel",
        integrityKey: key
    )
    let designation = SavedManualPhysicalKeyboardDesignation(
        identityKey: "identity:macos.keyboard.a|anchor:serial:s1",
        productName: "Board",
        confirmedName: "Travel",
        authenticationTag: tag
    )
    #expect(
        ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(
            designation,
            integrityKey: key
        )
    )

    let tampered = SavedManualPhysicalKeyboardDesignation(
        identityKey: designation.identityKey,
        productName: designation.productName,
        confirmedName: "Other",
        authenticationTag: tag
    )
    #expect(
        !ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(
            tampered,
            integrityKey: key
        )
    )
}

@Test("Designation evidence payload excludes Key Content fields")
func designationEvidencePayloadExcludesKeyContentFields() {
    let data = ManualPhysicalKeyboardDesignationAuthenticator.payloadData(
        identityKey: "identity:x|anchor:serial:s1",
        productName: "Board",
        confirmedName: "Name"
    )
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("identity:x|anchor:serial:s1"))
    #expect(text.contains("Board"))
    #expect(text.contains("Name"))
    #expect(!text.contains("keyCode"))
    #expect(!text.contains("usagePage"))
    #expect(!text.contains("modifier"))
}

// MARK: - Saved designations

@Test("Authentic saved designation makes an ambiguous Physical Keyboard assignable")
@MainActor
func authenticSavedDesignationMakesAmbiguousPhysicalKeyboardAssignable() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let designationStore = InMemoryManualPhysicalKeyboardDesignationStore()
    let integrityKey = InMemoryInstallationIntegrityKeyProvider()
    let discoverer = DesignationTestPhysicalKeyboardDiscoverer()
    let model = makeDesignationModel(
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKeyProvider: integrityKey,
        discoverer: discoverer
    )

    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 201, 202, identity: "macos.keyboard.amb")
    let keyboardID = model.physicalKeyboards[0].id
    #expect(model.physicalKeyboards[0].assignmentState == .unsupported(.ambiguousIdentity))

    saveDesignation(
        "Travel Board",
        for: keyboardID,
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKey: integrityKey
    )
    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 201, 202, identity: "macos.keyboard.amb")

    let designated = try #require(model.physicalKeyboards.first { $0.id == keyboardID })
    #expect(designated.isAssignable)
    #expect(designated.name == "Travel Board")
    #expect(designated.keyboardAssignment == nil)
}

@Test("Identity change does not auto migrate Manual Physical Keyboard Designation")
@MainActor
func identityChangeDoesNotAutoMigrateManualDesignation() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let designationStore = InMemoryManualPhysicalKeyboardDesignationStore()
    let integrityKey = InMemoryInstallationIntegrityKeyProvider()
    let discoverer = DesignationTestPhysicalKeyboardDiscoverer()
    let model = makeDesignationModel(
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKeyProvider: integrityKey,
        discoverer: discoverer
    )

    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 221, 222, identity: "macos.keyboard.old-amb")
    let oldID = model.physicalKeyboards[0].id
    saveDesignation(
        "Kept Name",
        for: oldID,
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKey: integrityKey
    )
    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 221, 222, identity: "macos.keyboard.old-amb")
    model.setKeyboardAssignment(oldID, inputSourceIdentifier: "com.example.us")

    discoverer.emit(.disconnected(serviceID: 221))
    discoverer.emit(.disconnected(serviceID: 222))

    connectAmbiguousGroup(discoverer, serviceIDs: 225, 226, identity: "macos.keyboard.new-amb")
    let newKeyboard = model.physicalKeyboards.first { $0.connectionState == .connected }
    #expect(newKeyboard?.id != oldID)
    #expect(newKeyboard?.assignmentState == .unsupported(.ambiguousIdentity))
    #expect(newKeyboard?.customName == nil)
    #expect(newKeyboard?.keyboardAssignment == nil)
    #expect(designationStore.designation(forIdentityKey: newKeyboard!.id.rawValue) == nil)
    #expect(designationStore.designation(forIdentityKey: oldID.rawValue) != nil)
    #expect(
        recordStore.record(forIdentityKey: oldID.rawValue)?.keyboardAssignment?
            .inputSourceIdentifier == "com.example.us"
    )
}

@Test("Tampered designation evidence leaves Physical Keyboard unsupported")
@MainActor
func tamperedDesignationEvidenceLeavesUnsupported() {
    let designationStore = InMemoryManualPhysicalKeyboardDesignationStore()
    let integrityKey = InMemoryInstallationIntegrityKeyProvider()
    let discoverer = DesignationTestPhysicalKeyboardDiscoverer()
    let model = makeDesignationModel(
        recordStore: InMemoryPhysicalKeyboardRecordStore(),
        designationStore: designationStore,
        integrityKeyProvider: integrityKey,
        discoverer: discoverer
    )

    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 231, 232, identity: "macos.keyboard.tamp")
    let keyboardID = model.physicalKeyboards[0].id

    designationStore.save(
        SavedManualPhysicalKeyboardDesignation(
            identityKey: keyboardID.rawValue,
            productName: "Ambiguous Board",
            confirmedName: "Forged",
            authenticationTag: Data(repeating: 0xAB, count: 32)
        )
    )
    startAndCheck(model)
    connectAmbiguousGroup(discoverer, serviceIDs: 231, 232, identity: "macos.keyboard.tamp")

    #expect(
        model.physicalKeyboards.first { $0.id == keyboardID }?
            .assignmentState == .unsupported(.ambiguousIdentity)
    )
    #expect(model.physicalKeyboards.first { $0.id == keyboardID }?.isAssignable == false)
}

// MARK: - Helpers

/// Saves a designation the way an earlier version of Keyameleon confirmed one.
@MainActor
private func saveDesignation(
    _ confirmedName: String,
    for keyboardID: PhysicalKeyboardRecordID,
    recordStore: InMemoryPhysicalKeyboardRecordStore,
    designationStore: InMemoryManualPhysicalKeyboardDesignationStore,
    integrityKey: InMemoryInstallationIntegrityKeyProvider
) {
    designationStore.save(
        SavedManualPhysicalKeyboardDesignation(
            identityKey: keyboardID.rawValue,
            productName: "Ambiguous Board",
            confirmedName: confirmedName,
            authenticationTag: ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
                identityKey: keyboardID.rawValue,
                productName: "Ambiguous Board",
                confirmedName: confirmedName,
                integrityKey: integrityKey.integrityKey()
            )
        )
    )
    recordStore.saveName(
        identityKey: keyboardID.rawValue,
        productName: "Ambiguous Board",
        customName: confirmedName
    )
}

@MainActor
private func makeDesignationModel(
    recordStore: any PhysicalKeyboardRecordStoring,
    designationStore: any ManualPhysicalKeyboardDesignationStoring,
    integrityKeyProvider: any InstallationIntegrityKeyProviding,
    discoverer: DesignationTestPhysicalKeyboardDiscoverer
) -> SetupModel {
    SetupModel(
        permissionProvider: DesignationTestListenPermissionProvider(state: .granted),
        setupStore: DesignationTestSetupDecisionStore(),
        inputMonitoringRecovery: DesignationTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore,
        designationStore: designationStore,
        integrityKeyProvider: integrityKeyProvider
    )
}

@MainActor
private func connectAmbiguousGroup(
    _ discoverer: DesignationTestPhysicalKeyboardDiscoverer,
    serviceIDs first: UInt64,
    _ second: UInt64,
    identity: String
) {
    discoverer.emit(
        .connected(
            makeDesignationHardwareFacts(
                serviceID: first,
                identity: identity,
                productID: 100,
                serialNumber: "same-serial"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeDesignationHardwareFacts(
                serviceID: second,
                identity: identity,
                productID: 200,
                serialNumber: "same-serial"
            )
        )
    )
}

private func makeDesignationHardwareFacts(
    serviceID: UInt64,
    identity: String,
    productID: UInt32,
    serialNumber: String?
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(
            rawValue: identity,
            isBuiltIn: false,
            serialNumber: serialNumber
        ),
        name: "Ambiguous Board",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 500,
        productID: productID,
        modelNumber: "Model",
        serialNumber: serialNumber
    )
}

@MainActor
private final class DesignationTestPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

@MainActor
private final class DesignationTestListenPermissionProvider: ListenPermissionProviding {
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
private final class DesignationTestSetupDecisionStore: SetupDecisionStoring {
    var hasStartedGuidedSetup = false
    var hasCompletedGuidedSetup = false
    var guidedSetupStep: GuidedSetupStep = .permission
    var isActivityTriggeredSwitchingPaused = false
    var hasEvaluatedBuiltInIdentityMigration = false
    private(set) var externalChangeResponse: ExternalChangeResponse = .switchBack

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

    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        externalChangeResponse = response
    }
}

@MainActor
private final class DesignationTestInputMonitoringRecovery: InputMonitoringRecovering {
    func openSystemSettings() {}
    func relaunch() {}
    func resetStaleGrantAfterRelaunch() async -> Bool { false }
}
