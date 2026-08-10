import Foundation
import Testing
@testable import Keyameleon

private enum QualificationActivationActivityClass: CaseIterable {
    case normal
    case modifier
    case function
    case media
    case lock
    case exposedSpecial
    case repeatActivity

    var eventKind: PhysicalKeyboardEventKind {
        self == .repeatActivity ? .repeat : .press
    }
}

@Test("Every supported Activation Activity class carries no Key Content")
@MainActor
func everySupportedActivationActivityClassCarriesNoKeyContent() {
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )
    let sentinelIdentity = "identity:macos.keyboard.SENTINEL_IDENTITY|anchor:serial:SENTINEL_SERIAL"

    service.startDiagnosticSession()
    for activityClass in QualificationActivationActivityClass.allCases {
        let event = PhysicalKeyboardEvent(serviceID: 1, kind: activityClass.eventKind)
        #expect(ActivationActivityClassification.isActivationActivity(event))
        service.record(
            code: .activationActivityAttributed,
            identityKey: sentinelIdentity,
            switchingStatus: nil
        )
    }

    #expect(!ActivationActivityClassification.isActivationActivity(.release))

    let bundleOutput = String(
        decoding: service.makeDiagnosticBundle().data,
        as: UTF8.self
    )
    #expect(!bundleOutput.contains("SENTINEL_IDENTITY"))
    #expect(!bundleOutput.contains("SENTINEL_SERIAL"))
    #expect(!bundleOutput.contains("KeyContentPayload"))
    #expect(
        service.allRecords().filter { $0.code == .activationActivityAttributed }.count
            == QualificationActivationActivityClass.allCases.count
    )
}

@Test("Physical Keyboard Identity and Keyboard Assignment lifecycle stays stable")
@MainActor
func physicalKeyboardIdentityAndKeyboardAssignmentLifecycleStaysStable() {
    let stableIdentity = PhysicalKeyboardIdentity(
        rawValue: "macos.keyboard.qualification",
        isBuiltIn: false,
        serialNumber: "qualification-serial"
    )
    let unstableIdentity = PhysicalKeyboardIdentity(
        rawValue: "macos.keyboard.unstable",
        isBuiltIn: false,
        serialNumber: nil
    )

    #expect(stableIdentity?.isStable == true)
    #expect(unstableIdentity?.isStable == false)

    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.qualification", name: "Qualification")
            ]
        ),
        physicalKeyboardRecordStore: recordStore
    )

    model.refreshPermission()
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 501,
                identity: "macos.keyboard.qualification",
                serialNumber: "qualification-serial"
            )
        )
    )

    let physicalKeyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(physicalKeyboardID, customName: "Qualification Keyboard")
    model.setKeyboardAssignment(
        physicalKeyboardID,
        inputSourceIdentifier: "com.example.qualification"
    )
    discoverer.emit(.disconnected(serviceID: 501))

    #expect(model.physicalKeyboards[0].connectionState == .disconnected)
    #expect(model.physicalKeyboards[0].name == "Qualification Keyboard")
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier
            == "com.example.qualification"
    )

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 502,
                identity: "macos.keyboard.qualification",
                serialNumber: "qualification-serial"
            )
        )
    )

    #expect(model.physicalKeyboards.count == 1)
    #expect(model.physicalKeyboards[0].id == physicalKeyboardID)
    #expect(model.physicalKeyboards[0].connectionState == .connected)
    #expect(
        model.physicalKeyboards[0].keyboardAssignment?.inputSourceIdentifier
            == "com.example.qualification"
    )

    model.setKeyboardAssignment(physicalKeyboardID, inputSourceIdentifier: nil)
    #expect(recordStore.record(forIdentityKey: physicalKeyboardID.rawValue)?.keyboardAssignment == nil)
}

@Test("Switching Status priority and warning recovery stay deterministic")
@MainActor
func switchingStatusPriorityAndWarningRecoveryStayDeterministic() {
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .denied,
            isTemporarilyUnavailable: true,
            isPaused: true
        ) == .permissionRequired
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: true,
            isPaused: true
        ) == .temporarilyUnavailable
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: false,
            isPaused: true
        ) == .paused
    )
    #expect(
        SwitchingStatus.resolve(
            listenPermission: .granted,
            isTemporarilyUnavailable: false,
            isPaused: false
        ) == .ready
    )

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(
        current: "com.example.other",
        verifySuccess: false
    )
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: "com.example.qualification", name: "Qualification"),
                EligibleInputSource(identifier: "com.example.other", name: "Other")
            ]
        ),
        inputSourceSelector: selector,
        diagnosticDataController: QualificationNoOpDiagnosticDataController()
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 503)))
    let physicalKeyboardID = model.physicalKeyboards[0].id
    model.setKeyboardAssignment(
        physicalKeyboardID,
        inputSourceIdentifier: "com.example.qualification"
    )

    for _ in 0..<100 {
        model.handlePhysicalKeyboardEvent(
            PhysicalKeyboardEvent(serviceID: 503, kind: .press)
        )
    }

    #expect(model.warningEpisodeCount == 1)
    #expect(model.activeWarnings.count == 1)
    #expect(model.activeWarnings[0].cause == .selectionFailure)

    selector.verifySuccess = true
    model.retryNow()

    #expect(model.activeWarnings.isEmpty)
    #expect(model.verifiedKeyboardAssignmentIdentifier == "com.example.qualification")
    #expect(selector.selectCount == 101)
    #expect(selector.readbackCount == selector.selectCount)
}

@Test("Deterministic stress processes 100,000 Physical Keyboard Events")
@MainActor
func deterministicStressProcesses100000PhysicalKeyboardEvents() {
    let totalEventCount = 100_000
    let serviceA: UInt64 = 601
    let serviceB: UInt64 = 602
    let serviceUnassigned: UInt64 = 603
    let sourceA = "com.example.qualification.a"
    let sourceB = "com.example.qualification.b"
    let externalSource = "com.example.qualification.external"

    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = QualificationCountingInputSourceSelector(current: externalSource)
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(
            inputSources: [
                EligibleInputSource(identifier: sourceA, name: "Qualification A"),
                EligibleInputSource(identifier: sourceB, name: "Qualification B"),
                EligibleInputSource(identifier: externalSource, name: "External")
            ]
        ),
        inputSourceSelector: selector,
        diagnosticDataController: QualificationNoOpDiagnosticDataController()
    )

    model.refreshPermission()
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: serviceA,
                identity: "macos.keyboard.qualification.a",
                serialNumber: "qualification-a"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: serviceB,
                identity: "macos.keyboard.qualification.b",
                serialNumber: "qualification-b"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: serviceUnassigned,
                identity: "macos.keyboard.qualification.unassigned",
                serialNumber: "qualification-unassigned"
            )
        )
    )

    let keyboardAID = model.physicalKeyboards.first {
        $0.id.rawValue.contains("qualification.a")
    }!.id
    let keyboardBID = model.physicalKeyboards.first {
        $0.id.rawValue.contains("qualification.b")
    }!.id
    model.setKeyboardAssignment(keyboardAID, inputSourceIdentifier: sourceA)
    model.setKeyboardAssignment(keyboardBID, inputSourceIdentifier: sourceB)

    var expectedCurrent = externalSource
    var expectedVerified: String?
    var expectedWanted: String?
    var expectedSelectionCount = 0
    var expectedSelectionCounts: [String: Int] = [:]

    for index in 0..<totalEventCount {
        let action = qualificationStressAction(
            at: index,
            totalEventCount: totalEventCount,
            serviceA: serviceA,
            serviceB: serviceB,
            serviceUnassigned: serviceUnassigned
        )

        if let externalIdentifier = action.externalInputSourceIdentifier {
            expectedCurrent = externalIdentifier
            expectedVerified = nil
        }

        guard ActivationActivityClassification.isActivationActivity(action.event),
              let wantedIdentifier = action.wantedInputSourceIdentifier
        else {
            continue
        }

        if expectedWanted == wantedIdentifier,
           expectedVerified == wantedIdentifier,
           expectedCurrent == wantedIdentifier
        {
            continue
        }

        expectedWanted = wantedIdentifier
        expectedVerified = wantedIdentifier
        expectedCurrent = wantedIdentifier
        expectedSelectionCount += 1
        expectedSelectionCounts[wantedIdentifier, default: 0] += 1
    }

    for index in 0..<totalEventCount {
        let action = qualificationStressAction(
            at: index,
            totalEventCount: totalEventCount,
            serviceA: serviceA,
            serviceB: serviceB,
            serviceUnassigned: serviceUnassigned
        )

        if let externalIdentifier = action.externalInputSourceIdentifier {
            selector.current = externalIdentifier
            model.handleExternalInputSourceChange()
        }
        model.handlePhysicalKeyboardEvent(action.event)
    }

    #expect(expectedSelectionCount > 0)
    #expect(selector.selectCount == expectedSelectionCount)
    #expect(selector.readbackCount == expectedSelectionCount)
    #expect(selector.selectionCounts == expectedSelectionCounts)
    #expect(model.inputSourceSelectionRequestCount == expectedSelectionCount)
    #expect(model.wantedKeyboardAssignmentGeneration == UInt64(expectedSelectionCount))
    #expect(model.activePhysicalKeyboardID == keyboardBID)
    #expect(model.wantedKeyboardAssignmentIdentifier == sourceB)
    #expect(model.verifiedKeyboardAssignmentIdentifier == sourceB)
    #expect(model.observedCurrentInputSourceIdentifier == sourceB)
    #expect(selector.current == sourceB)
}

private struct QualificationStressAction {
    let event: PhysicalKeyboardEvent
    let externalInputSourceIdentifier: String?
    let wantedInputSourceIdentifier: String?
}

private func qualificationStressAction(
    at index: Int,
    totalEventCount: Int,
    serviceA: UInt64,
    serviceB: UInt64,
    serviceUnassigned: UInt64
) -> QualificationStressAction {
    if index == totalEventCount - 1 {
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceB, kind: .press),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: "com.example.qualification.b"
        )
    }

    if index % 4_096 == 2_048 {
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceA, kind: .press),
            externalInputSourceIdentifier: "com.example.qualification.external",
            wantedInputSourceIdentifier: "com.example.qualification.a"
        )
    }

    switch index % 8 {
    case 0:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceA, kind: .release),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: nil
        )
    case 1:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: 60_999, kind: .press),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: nil
        )
    case 2:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceUnassigned, kind: .press),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: nil
        )
    case 3, 5:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceB, kind: .repeat),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: "com.example.qualification.b"
        )
    case 4, 7:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceA, kind: .press),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: "com.example.qualification.a"
        )
    default:
        return QualificationStressAction(
            event: PhysicalKeyboardEvent(serviceID: serviceB, kind: .press),
            externalInputSourceIdentifier: nil,
            wantedInputSourceIdentifier: "com.example.qualification.b"
        )
    }
}

@MainActor
private final class QualificationCountingInputSourceSelector: InputSourceSelecting {
    var current: String?
    private(set) var selectCount = 0
    private(set) var readbackCount = 0
    private(set) var selectionCounts: [String: Int] = [:]

    init(current: String?) {
        self.current = current
    }

    func currentInputSourceIdentifier() -> String? {
        current
    }

    func selectAndVerifyInputSource(identifier: String) -> Bool {
        selectCount += 1
        selectionCounts[identifier, default: 0] += 1
        current = identifier
        readbackCount += 1
        return current == identifier
    }
}

@MainActor
private final class QualificationNoOpDiagnosticDataController: DiagnosticDataControlling {
    var onChange: (@MainActor () -> Void)?
    var isDiagnosticSessionActive = false
    var diagnosticSessionStartedAt: Date?
    var recordCount = 0
    var estimatedByteCount = 0

    func startDiagnosticSession() {}

    func stopDiagnosticSession() {}

    func enforceSessionLimit() {}

    func clearAllDiagnosticData() {}

    func deleteDiagnosticData(forIdentityKey identityKey: String) {}

    func temporaryToken(forIdentityKey identityKey: String) -> TemporaryPhysicalKeyboardToken {
        TemporaryPhysicalKeyboardToken(
            rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )
    }

    func record(
        code: DiagnosticEventCode,
        identityKey: String?,
        switchingStatus: SwitchingStatus?
    ) {}

    func makeDiagnosticBundle() -> DiagnosticBundle {
        DiagnosticBundleBuilder.make(records: [], createdAt: Date(timeIntervalSince1970: 0))
    }

    func allRecords() -> [DiagnosticRecord] {
        []
    }

    func enforceRetention() {}
}
