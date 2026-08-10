import Foundation
import Testing
@testable import Keyameleon

// MARK: - Domain policy

@Test("Default mode allows only operational errors, state changes, and session lifecycle")
func defaultModeAllowsOnlyOperationalAndSessionLifecycle() {
    #expect(
        DiagnosticDataPolicy.isAllowed(.inputSourceSelectionFailed, mode: .defaultMode)
    )
    #expect(
        DiagnosticDataPolicy.isAllowed(.switchingStatusChanged, mode: .defaultMode)
    )
    #expect(
        DiagnosticDataPolicy.isAllowed(.diagnosticSessionStarted, mode: .defaultMode)
    )
    #expect(
        !DiagnosticDataPolicy.isAllowed(.activationActivityAttributed, mode: .defaultMode)
    )
    #expect(
        !DiagnosticDataPolicy.isAllowed(.inputSourceSelectionSucceeded, mode: .defaultMode)
    )
}

@Test("Diagnostic Session mode allows detailed allowlisted categories")
func diagnosticSessionModeAllowsDetailedAllowlistedCategories() {
    #expect(
        DiagnosticDataPolicy.isAllowed(.activationActivityAttributed, mode: .diagnosticSession)
    )
    #expect(
        DiagnosticDataPolicy.isAllowed(.inputSourceSelectionSucceeded, mode: .diagnosticSession)
    )
    #expect(
        DiagnosticDataPolicy.isAllowed(.inputSourceSelectionFailed, mode: .diagnosticSession)
    )
}

@Test("Diagnostic Session expires at 10 minutes")
func diagnosticSessionExpiresAtTenMinutes() {
    let started = Date(timeIntervalSince1970: 1_000)
    #expect(
        !DiagnosticSessionTiming.isExpired(
            startedAt: started,
            now: started.addingTimeInterval(10 * 60 - 1)
        )
    )
    #expect(
        DiagnosticSessionTiming.isExpired(
            startedAt: started,
            now: started.addingTimeInterval(10 * 60)
        )
    )
}

@Test("Retention deletes oldest first for age and size limits")
func retentionDeletesOldestFirstForAgeAndSizeLimits() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let old = DiagnosticRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        recordedAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
        code: .switchingStatusChanged
    )
    let mid = DiagnosticRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        recordedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
        code: .assignmentSaved
    )
    let newest = DiagnosticRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        recordedAt: now.addingTimeInterval(-1 * 60 * 60),
        code: .assignmentRemoved
    )

    let ageDeletes = DiagnosticRetention.recordIDsToDelete(
        records: [mid, newest, old],
        now: now
    )
    #expect(ageDeletes == [old.id])

    // Force size limit: max 1 record worth of bytes.
    let sizeDeletes = DiagnosticRetention.recordIDsToDelete(
        records: [mid, newest],
        now: now,
        maximumAge: DiagnosticDataPolicy.maximumRetentionAge,
        maximumByteCount: DiagnosticDataPolicy.estimatedBytesPerRecord
    )
    #expect(sizeDeletes == [mid.id])
}

@Test("Diagnostic records use temporary tokens not identity values")
func diagnosticRecordsUseTemporaryTokensNotIdentityValues() {
    let token = TemporaryPhysicalKeyboardToken(
        rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    )
    let record = DiagnosticRecord(
        recordedAt: Date(timeIntervalSince1970: 0),
        code: .physicalKeyboardConnected,
        physicalKeyboardToken: token
    )

    #expect(record.physicalKeyboardToken == token)
    #expect(record.category == .operationalStateChange)
    // Closed schema: no free-form identity/name/path fields exist on the type.
    #expect(DiagnosticDataExclusion.forbiddenFieldLabels.count == 11)
}

// MARK: - Service

@MainActor
@Test("User starts and stops Diagnostic Session")
func userStartsAndStopsDiagnosticSession() {
    let clock = ManualClock()
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: clock
    )

    #expect(!service.isDiagnosticSessionActive)

    service.startDiagnosticSession()
    #expect(service.isDiagnosticSessionActive)
    #expect(service.allRecords().map(\.code) == [.diagnosticSessionStarted])

    service.stopDiagnosticSession()
    #expect(!service.isDiagnosticSessionActive)
    #expect(
        service.allRecords().map(\.code)
            == [.diagnosticSessionStarted, .diagnosticSessionStopped]
    )
}

@MainActor
@Test("Diagnostic Session ends automatically after 10 minutes")
func diagnosticSessionEndsAutomaticallyAfterTenMinutes() {
    let clock = ManualClock()
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: clock
    )

    service.startDiagnosticSession()
    clock.advance(by: 10 * 60)
    service.enforceSessionLimit()

    #expect(!service.isDiagnosticSessionActive)
    #expect(service.allRecords().last?.code == .diagnosticSessionExpired)
}

@MainActor
@Test("Default recording rejects session-only codes and never stores free-form values")
func defaultRecordingRejectsSessionOnlyCodes() {
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )

    service.record(code: .activationActivityAttributed, identityKey: nil, switchingStatus: nil)
    service.record(code: .inputSourceSelectionSucceeded, identityKey: nil, switchingStatus: nil)
    service.record(
        code: .switchingStatusChanged,
        identityKey: nil,
        switchingStatus: .permissionRequired
    )

    let codes = service.allRecords().map(\.code)
    #expect(codes == [.switchingStatusChanged])
    #expect(service.allRecords()[0].switchingStatus == .permissionRequired)
}

@MainActor
@Test("Diagnostic Session records detailed allowlisted events with sequence and timing")
func diagnosticSessionRecordsDetailedAllowlistedEvents() {
    let clock = ManualClock()
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: clock
    )

    service.startDiagnosticSession()
    clock.advance(by: 1.5)
    service.record(
        code: .activationActivityAttributed,
        identityKey: "identity:secret|anchor:serial:SENSITIVE",
        switchingStatus: nil
    )
    clock.advance(by: 0.25)
    service.record(
        code: .inputSourceSelectionSucceeded,
        identityKey: "identity:secret|anchor:serial:SENSITIVE",
        switchingStatus: nil
    )

    let records = service.allRecords().filter {
        $0.code == .activationActivityAttributed || $0.code == .inputSourceSelectionSucceeded
    }
    #expect(records.count == 2)
    #expect(records[0].code == .activationActivityAttributed)
    #expect(records[0].sequenceNumber == 1)
    #expect(records[1].code == .inputSourceSelectionSucceeded)
    #expect(records[1].sequenceNumber == 2)
    #expect(records[0].relativeMilliseconds == 1_500)

    // No exact identity value appears in stored Diagnostic Data.
    for record in records {
        #expect(record.physicalKeyboardToken != nil)
        let tokenString = record.physicalKeyboardToken!.rawValue.uuidString
        #expect(!tokenString.contains("secret"))
        #expect(!tokenString.contains("SENSITIVE"))
        #expect(!tokenString.contains("serial"))
    }
}

@MainActor
@Test("Default mode does not record one Diagnostic Data entry per Physical Keyboard Event")
func defaultModeDoesNotRecordOneEntryPerPhysicalKeyboardEvent() {
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )

    // Simulate many Activation Activity attributions outside a session — all rejected.
    for _ in 0..<100 {
        service.record(
            code: .activationActivityAttributed,
            identityKey: "identity:k|anchor:serial:s",
            switchingStatus: nil
        )
    }

    #expect(service.recordCount == 0)
}

@MainActor
@Test("Clear all removes Diagnostic Data")
func clearAllRemovesDiagnosticData() {
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )

    service.record(code: .discoveryFailed, identityKey: nil, switchingStatus: nil)
    service.record(code: .permissionDenied, identityKey: nil, switchingStatus: nil)
    #expect(service.recordCount == 2)

    service.clearAllDiagnosticData()
    #expect(service.recordCount == 0)
}

@MainActor
@Test("Forget deletes Diagnostic Data linked to that Physical Keyboard")
func forgetDeletesDiagnosticDataLinkedToPhysicalKeyboard() {
    let service = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )
    let identityA = "identity:a|anchor:serial:a"
    let identityB = "identity:b|anchor:serial:b"

    service.record(code: .physicalKeyboardConnected, identityKey: identityA, switchingStatus: nil)
    service.record(code: .physicalKeyboardConnected, identityKey: identityB, switchingStatus: nil)
    service.record(code: .assignmentSaved, identityKey: identityA, switchingStatus: nil)
    #expect(service.recordCount == 3)

    service.deleteDiagnosticData(forIdentityKey: identityA)

    let remaining = service.allRecords()
    #expect(remaining.count == 1)
    #expect(remaining[0].code == .physicalKeyboardConnected)
    // Remaining record is B's token, not A's.
    let tokenB = service.temporaryToken(forIdentityKey: identityB)
    #expect(remaining[0].physicalKeyboardToken == tokenB)
}

@MainActor
@Test("Retention enforces 7-day and 5 MB limits on store")
func retentionEnforcesSevenDayAndFiveMegabyteLimitsOnStore() {
    let clock = ManualClock(now: Date(timeIntervalSince1970: 20_000_000))
    let store = InMemoryDiagnosticDataStore()
    let service = KeyameleonDiagnosticDataService(store: store, clock: clock)

    // Insert an expired record directly, then prune.
    store.insert(
        DiagnosticRecord(
            recordedAt: clock.now().addingTimeInterval(-8 * 24 * 60 * 60),
            code: .discoveryFailed
        )
    )
    store.insert(
        DiagnosticRecord(
            recordedAt: clock.now().addingTimeInterval(-1 * 24 * 60 * 60),
            code: .permissionDenied
        )
    )
    service.enforceRetention()

    #expect(service.recordCount == 1)
    #expect(service.allRecords()[0].code == .permissionDenied)

    // Size: fill beyond 5 MB using estimated size.
    let maxRecords = DiagnosticDataPolicy.maximumByteCount
        / DiagnosticDataPolicy.estimatedBytesPerRecord
    for _ in 0..<(maxRecords + 10) {
        store.insert(
            DiagnosticRecord(
                recordedAt: clock.now(),
                code: .switchingStatusChanged,
                switchingStatus: .ready
            )
        )
    }
    service.enforceRetention()

    #expect(service.recordCount <= maxRecords)
    #expect(service.estimatedByteCount <= DiagnosticDataPolicy.maximumByteCount)
}

@MainActor
@Test("Forget on SetupModel also clears linked Diagnostic Data")
func forgetOnSetupModelAlsoClearsLinkedDiagnosticData() {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let diagnostic = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let model = KeyameleonSetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: recordStore,
        diagnosticDataController: diagnostic
    )

    model.refreshPermission()
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 301)))
    let keyboardID = model.physicalKeyboards[0].id
    model.setPhysicalKeyboardName(keyboardID, customName: "Travel")
    model.setKeyboardAssignment(keyboardID, inputSourceIdentifier: "com.example.us")

    // SetupModel already records connect + assignmentSaved with this keyboard token.
    #expect(diagnostic.recordCount >= 1)
    #expect(
        diagnostic.allRecords().contains { $0.physicalKeyboardToken != nil }
    )

    model.forgetPhysicalKeyboard(keyboardID)

    #expect(diagnostic.recordCount == 0)
    #expect(recordStore.record(forIdentityKey: keyboardID.rawValue) == nil)
}

@MainActor
@Test("General settings starts, stops, and clears Diagnostic Data")
func generalSettingsStartsStopsAndClearsDiagnosticData() {
    let diagnostic = KeyameleonDiagnosticDataService(
        store: InMemoryDiagnosticDataStore(),
        clock: ManualClock()
    )
    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
        updateChecker: FakeUpdateChecker(canCheck: true),
        diagnosticDataController: diagnostic
    )

    model.startDiagnosticSession()
    #expect(model.isDiagnosticSessionActive)
    #expect(diagnostic.isDiagnosticSessionActive)

    model.stopDiagnosticSession()
    #expect(!model.isDiagnosticSessionActive)

    model.clearAllDiagnosticData()
    #expect(model.diagnosticRecordCount == 0)

    diagnostic.record(code: .discoveryFailed, identityKey: nil, switchingStatus: nil)
    model.refresh()
    #expect(model.diagnosticRecordCount == 1)

    model.clearAllDiagnosticData()
    #expect(model.diagnosticRecordCount == 0)
    #expect(diagnostic.recordCount == 0)
}

@MainActor
@Test("Diagnostic records never embed identity, serial, name, path, or Key Content sentinels")
func diagnosticRecordsNeverEmbedSensitiveSentinels() {
    let identityKey = "identity:macos.keyboard.SENTINEL_IDENTITY|anchor:serial:SENTINEL_SERIAL"
    let store = InMemoryDiagnosticDataStore()
    let service = KeyameleonDiagnosticDataService(
        store: store,
        clock: ManualClock()
    )

    service.startDiagnosticSession()
    service.record(
        code: .activationActivityAttributed,
        identityKey: identityKey,
        switchingStatus: .ready
    )
    service.record(
        code: .inputSourceSelectionSucceeded,
        identityKey: identityKey,
        switchingStatus: nil
    )

    let sensitive = [
        "SENTINEL_IDENTITY",
        "SENTINEL_SERIAL",
        "Travel Keyboard",
        "com.example.us",
        "/Users/sensitive",
        "KeyContentPayload",
    ]

    for record in service.allRecords() {
        let mirror = String(describing: record)
        for sentinel in sensitive {
            #expect(!mirror.contains(sentinel), "record leaked \(sentinel): \(mirror)")
        }
    }

    // Linkage map stores only a SHA-256 digest, never the identity key plaintext.
    let linkage = DiagnosticIdentityLinkageKey(identityKey: identityKey)
    #expect(store.token(forLinkageKey: linkage) != nil)
    #expect(!linkage.rawValue.contains("SENTINEL"))
    #expect(linkage.rawValue.count == 64)
}
