import CryptoKit
import Foundation
import Testing
@testable import Keyameleon

// MARK: - Evidence rules

@Test("Manual Physical Keyboard Designation offered only for external ambiguous identity groups")
func manualDesignationOfferedOnlyForExternalAmbiguousIdentityGroups() {
    let ambiguous = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.a|anchor:serial:s1"),
        productName: "Ambiguous Board",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unsupported(.ambiguousIdentity),
        connectedServiceCount: 2,
        connectionState: .connected,
        isActive: false
    )
    #expect(ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: ambiguous))

    let missing = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "service:1"),
        productName: "No ID",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unsupported(.missingIdentity),
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
    #expect(!ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: missing))

    let shared = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.a|anchor:serial:s1"),
        productName: "Shared",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unsupported(.sharedIdentity),
        connectedServiceCount: 2,
        connectionState: .connected,
        isActive: false
    )
    #expect(!ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: shared))

    let unstable = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.a|anchor:unstable"),
        productName: "Unstable",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unsupported(.unstableIdentity),
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
    #expect(!ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: unstable))

    let builtInAmbiguous = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.builtin|anchor:built-in"),
        productName: "Built-in",
        customName: nil,
        transport: .other,
        isBuiltIn: true,
        assignmentState: .unsupported(.ambiguousIdentity),
        connectedServiceCount: 2,
        connectionState: .connected,
        isActive: false
    )
    #expect(!ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: builtInAmbiguous))

    let assignable = PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: "identity:macos.keyboard.a|anchor:serial:s1"),
        productName: "OK",
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unassigned,
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
    #expect(!ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(for: assignable))
}

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

// MARK: - SetupModel flow

@Test("Manual designation requires leave, return, and explicit name confirmation")
@MainActor
func manualDesignationRequiresLeaveReturnAndExplicitNameConfirmation() {
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

    model.refreshPermission()
    connectAmbiguousGroup(discoverer, serviceIDs: 201, 202, identity: "macos.keyboard.amb")
    let keyboardID = model.physicalKeyboards[0].id
    #expect(model.canStartManualDesignation(for: keyboardID))
    #expect(model.physicalKeyboards[0].assignmentState == .unsupported(.ambiguousIdentity))

    model.startManualDesignation(for: keyboardID)
    #expect(model.manualDesignationPhase == .awaitingRemoval(keyboardID))

    // Other keyboard still assignable during flow.
    discoverer.emit(
        .connected(
            makeDesignationHardwareFacts(
                serviceID: 301,
                identity: "macos.keyboard.other",
                productID: 50,
                serialNumber: "other-serial"
            )
        )
    )
    let otherID = model.physicalKeyboards.first {
        $0.id != keyboardID && $0.isAssignable
    }?.id
    #expect(otherID != nil)
    if let otherID {
        model.setKeyboardAssignment(otherID, inputSourceIdentifier: "com.example.us")
        #expect(
            model.physicalKeyboards.first { $0.id == otherID }?
                .keyboardAssignment?.inputSourceIdentifier == "com.example.us"
        )
    }

    discoverer.emit(.disconnected(serviceID: 201))
    discoverer.emit(.disconnected(serviceID: 202))
    #expect(model.manualDesignationPhase == .awaitingReturn(keyboardID))

    connectAmbiguousGroup(discoverer, serviceIDs: 203, 204, identity: "macos.keyboard.amb")
    #expect(
        model.manualDesignationPhase
            == .awaitingNameConfirmation(keyboardID, productName: "Ambiguous Board")
    )

    // No designation yet without name confirmation.
    #expect(designationStore.designation(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(model.physicalKeyboards.first { $0.id == keyboardID }?.isAssignable == false)

    model.confirmManualDesignationName("Travel Board")

    #expect(model.manualDesignationPhase == .idle)
    let designated = model.physicalKeyboards.first { $0.id == keyboardID }
    #expect(designated?.isAssignable == true)
    #expect(designated?.name == "Travel Board")
    #expect(designated?.keyboardAssignment == nil)
    #expect(designationStore.designation(forIdentityKey: keyboardID.rawValue) != nil)
    #expect(
        recordStore.record(forIdentityKey: keyboardID.rawValue)?.customName == "Travel Board"
    )
    #expect(
        ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(
            designationStore.designation(forIdentityKey: keyboardID.rawValue)!,
            integrityKey: integrityKey.integrityKey()
        )
    )
}

@Test("Shared return evidence is not accepted and creates no designation or assignment")
@MainActor
func sharedReturnEvidenceIsNotAcceptedAndCreatesNoDesignationOrAssignment() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let designationStore = InMemoryManualPhysicalKeyboardDesignationStore()
    let discoverer = DesignationTestPhysicalKeyboardDiscoverer()
    let model = makeDesignationModel(
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKeyProvider: InMemoryInstallationIntegrityKeyProvider(),
        discoverer: discoverer
    )

    model.refreshPermission()
    connectAmbiguousGroup(discoverer, serviceIDs: 211, 212, identity: "macos.keyboard.amb2")
    let keyboardID = model.physicalKeyboards[0].id
    model.startManualDesignation(for: keyboardID)
    discoverer.emit(.disconnected(serviceID: 211))
    discoverer.emit(.disconnected(serviceID: 212))
    #expect(model.manualDesignationPhase == .awaitingReturn(keyboardID))

    // Shared serials change identity anchors → different record; original group not accepted.
    discoverer.emit(
        .connected(
            makeDesignationHardwareFacts(
                serviceID: 213,
                identity: "macos.keyboard.amb2",
                productID: 100,
                serialNumber: "serial-a"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeDesignationHardwareFacts(
                serviceID: 214,
                identity: "macos.keyboard.amb2",
                productID: 100,
                serialNumber: "serial-b"
            )
        )
    )

    #expect(model.manualDesignationPhase == .awaitingReturn(keyboardID))
    #expect(designationStore.designation(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(
        model.physicalKeyboards.contains {
            if case .unsupported(.sharedIdentity) = $0.assignmentState {
                return true
            }
            return false
        }
    )

    model.cancelManualDesignation()
    #expect(model.manualDesignationPhase == .idle)
    #expect(designationStore.allDesignations().isEmpty)
}

@Test("Empty confirmed name is incomplete evidence and creates no designation")
@MainActor
func emptyConfirmedNameIsIncompleteEvidenceAndCreatesNoDesignation() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let designationStore = InMemoryManualPhysicalKeyboardDesignationStore()
    let discoverer = DesignationTestPhysicalKeyboardDiscoverer()
    let model = makeDesignationModel(
        recordStore: recordStore,
        designationStore: designationStore,
        integrityKeyProvider: InMemoryInstallationIntegrityKeyProvider(),
        discoverer: discoverer
    )

    model.refreshPermission()
    connectAmbiguousGroup(discoverer, serviceIDs: 241, 242, identity: "macos.keyboard.empty-name")
    let keyboardID = model.physicalKeyboards[0].id
    model.startManualDesignation(for: keyboardID)
    discoverer.emit(.disconnected(serviceID: 241))
    discoverer.emit(.disconnected(serviceID: 242))
    connectAmbiguousGroup(discoverer, serviceIDs: 243, 244, identity: "macos.keyboard.empty-name")
    #expect(
        model.manualDesignationPhase
            == .awaitingNameConfirmation(keyboardID, productName: "Ambiguous Board")
    )

    model.confirmManualDesignationName("   ")
    #expect(
        model.manualDesignationPhase
            == .awaitingNameConfirmation(keyboardID, productName: "Ambiguous Board")
    )
    #expect(designationStore.designation(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue) == nil)
    #expect(model.physicalKeyboards.first { $0.id == keyboardID }?.isAssignable == false)
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

    model.refreshPermission()
    connectAmbiguousGroup(discoverer, serviceIDs: 221, 222, identity: "macos.keyboard.old-amb")
    let oldID = model.physicalKeyboards[0].id
    model.startManualDesignation(for: oldID)
    discoverer.emit(.disconnected(serviceID: 221))
    discoverer.emit(.disconnected(serviceID: 222))
    connectAmbiguousGroup(discoverer, serviceIDs: 223, 224, identity: "macos.keyboard.old-amb")
    model.confirmManualDesignationName("Kept Name")
    model.setKeyboardAssignment(oldID, inputSourceIdentifier: "com.example.us")

    discoverer.emit(.disconnected(serviceID: 223))
    discoverer.emit(.disconnected(serviceID: 224))

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

    model.refreshPermission()
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
    model.refreshPermission()
    connectAmbiguousGroup(discoverer, serviceIDs: 231, 232, identity: "macos.keyboard.tamp")

    #expect(
        model.physicalKeyboards.first { $0.id == keyboardID }?
            .assignmentState == .unsupported(.ambiguousIdentity)
    )
    #expect(model.physicalKeyboards.first { $0.id == keyboardID }?.isAssignable == false)
}

// MARK: - Helpers

@MainActor
private func makeDesignationModel(
    recordStore: any PhysicalKeyboardRecordStoring,
    designationStore: any ManualPhysicalKeyboardDesignationStoring,
    integrityKeyProvider: any InstallationIntegrityKeyProviding,
    discoverer: DesignationTestPhysicalKeyboardDiscoverer
) -> KeyameleonSetupModel {
    KeyameleonSetupModel(
        permissionProvider: DesignationTestListenPermissionProvider(state: .granted),
        setupStore: DesignationTestSetupDecisionStore(),
        systemSettingsOpener: DesignationTestSystemSettingsOpener(),
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
}

@MainActor
private final class DesignationTestSystemSettingsOpener: SystemSettingsOpening {
    func openSystemSettings() {}
}
