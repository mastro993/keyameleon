import Foundation
@preconcurrency import SwiftData

// MARK: - Clock

protocol ClockProviding: Sendable {
    func now() -> Date
}

struct SystemClock: ClockProviding {
    func now() -> Date {
        Date()
    }
}

final class ManualClock: ClockProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = now
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }
}

// MARK: - Store

@MainActor
protocol DiagnosticDataStoring: AnyObject {
    func allRecords() -> [DiagnosticRecord]
    func insert(_ record: DiagnosticRecord)
    func delete(ids: [UUID])
    func deleteAll()
    func delete(matchingToken token: TemporaryPhysicalKeyboardToken)
    func token(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey) -> TemporaryPhysicalKeyboardToken?
    func setToken(_ token: TemporaryPhysicalKeyboardToken, forLinkageKey linkageKey: DiagnosticIdentityLinkageKey)
    func removeToken(forLinkageKey linkageKey: DiagnosticIdentityLinkageKey)
}

// MARK: - Controlling seam

@MainActor
protocol DiagnosticDataControlling: AnyObject {
    var onChange: (@MainActor () -> Void)? { get set }
    var isDiagnosticSessionActive: Bool { get }
    var diagnosticSessionStartedAt: Date? { get }
    var recordCount: Int { get }
    var estimatedByteCount: Int { get }

    func startDiagnosticSession()
    func stopDiagnosticSession()
    /// Expires an active Diagnostic Session when past the 10-minute limit.
    func enforceSessionLimit()
    func clearAllDiagnosticData()
    /// Removes Diagnostic Data linked to the forgotten Physical Keyboard identity key.
    func deleteDiagnosticData(forIdentityKey identityKey: String)
    func temporaryToken(forIdentityKey identityKey: String) -> TemporaryPhysicalKeyboardToken
    /// Records an allowlisted event. Rejected codes for the current mode are ignored.
    func record(
        code: DiagnosticEventCode,
        identityKey: String?,
        switchingStatus: SwitchingStatus?
    )
    func makeDiagnosticBundle() -> DiagnosticBundle
    func allRecords() -> [DiagnosticRecord]
    func enforceRetention()
}

// MARK: - Service

@MainActor
final class KeyameleonDiagnosticDataService: DiagnosticDataControlling {
    var onChange: (@MainActor () -> Void)?
    private let store: any DiagnosticDataStoring
    private let clock: any ClockProviding
    private var sessionStartedAt: Date?
    private var sessionSequence: UInt64 = 0
    private var nextInsertionOrder: UInt64 = 1
    private var sessionExpiryTask: Task<Void, Never>?

    init(
        store: any DiagnosticDataStoring,
        clock: any ClockProviding = SystemClock()
    ) {
        self.store = store
        self.clock = clock
        if let maxOrder = store.allRecords().map(\.insertionOrder).max() {
            nextInsertionOrder = maxOrder + 1
        }
        enforceRetention()
    }

    var isDiagnosticSessionActive: Bool {
        enforceSessionLimit()
        return sessionStartedAt != nil
    }

    var diagnosticSessionStartedAt: Date? {
        enforceSessionLimit()
        return sessionStartedAt
    }

    var recordCount: Int {
        store.allRecords().count
    }

    var estimatedByteCount: Int {
        DiagnosticDataPolicy.estimatedByteCount(forRecordCount: recordCount)
    }

    func startDiagnosticSession() {
        enforceSessionLimit()
        guard sessionStartedAt == nil else {
            return
        }

        let now = clock.now()
        sessionStartedAt = now
        sessionSequence = 0
        insertRecord(
            makeRecord(
                recordedAt: now,
                code: .diagnosticSessionStarted,
                relativeMilliseconds: 0
            )
        )
        scheduleSessionExpiry(from: now)
    }

    func stopDiagnosticSession() {
        guard let startedAt = sessionStartedAt else {
            return
        }

        let now = clock.now()
        let relative = DiagnosticSessionTiming.relativeMilliseconds(startedAt: startedAt, now: now)
        sessionStartedAt = nil
        sessionSequence = 0
        cancelSessionExpiry()
        insertRecord(
            makeRecord(
                recordedAt: now,
                code: .diagnosticSessionStopped,
                relativeMilliseconds: relative
            )
        )
    }

    func enforceSessionLimit() {
        guard let startedAt = sessionStartedAt else {
            return
        }

        let now = clock.now()
        guard DiagnosticSessionTiming.isExpired(startedAt: startedAt, now: now) else {
            return
        }

        let relative = DiagnosticSessionTiming.relativeMilliseconds(startedAt: startedAt, now: now)
        sessionStartedAt = nil
        sessionSequence = 0
        cancelSessionExpiry()
        insertRecord(
            makeRecord(
                recordedAt: now,
                code: .diagnosticSessionExpired,
                relativeMilliseconds: relative
            )
        )
    }

    func clearAllDiagnosticData() {
        store.deleteAll()
        onChange?()
    }

    func deleteDiagnosticData(forIdentityKey identityKey: String) {
        let linkageKey = DiagnosticIdentityLinkageKey(identityKey: identityKey)
        if let token = store.token(forLinkageKey: linkageKey) {
            store.delete(matchingToken: token)
            store.removeToken(forLinkageKey: linkageKey)
            onChange?()
        }
    }

    func temporaryToken(forIdentityKey identityKey: String) -> TemporaryPhysicalKeyboardToken {
        let linkageKey = DiagnosticIdentityLinkageKey(identityKey: identityKey)
        if let existing = store.token(forLinkageKey: linkageKey) {
            return existing
        }

        let token = TemporaryPhysicalKeyboardToken()
        store.setToken(token, forLinkageKey: linkageKey)
        return token
    }

    func record(
        code: DiagnosticEventCode,
        identityKey: String? = nil,
        switchingStatus: SwitchingStatus? = nil
    ) {
        enforceSessionLimit()

        let mode: DiagnosticRecordingMode =
            sessionStartedAt == nil ? .defaultMode : .diagnosticSession
        guard DiagnosticDataPolicy.isAllowed(code, mode: mode) else {
            return
        }

        // Session lifecycle codes use start/stop/expire APIs only.
        switch code {
        case .diagnosticSessionStarted, .diagnosticSessionStopped, .diagnosticSessionExpired:
            return
        default:
            break
        }

        let now = clock.now()
        let token = identityKey.map { temporaryToken(forIdentityKey: $0) }
        var sequence: UInt64?
        var relative: Int64?

        if let startedAt = sessionStartedAt {
            sessionSequence += 1
            sequence = sessionSequence
            relative = DiagnosticSessionTiming.relativeMilliseconds(startedAt: startedAt, now: now)
        }

        insertRecord(
            makeRecord(
                recordedAt: now,
                code: code,
                physicalKeyboardToken: token,
                sequenceNumber: sequence,
                relativeMilliseconds: relative,
                switchingStatus: switchingStatus
            )
        )
    }

    func allRecords() -> [DiagnosticRecord] {
        enforceRetention()
        return store.allRecords().sorted(by: DiagnosticRecord.oldestFirst)
    }

    func makeDiagnosticBundle() -> DiagnosticBundle {
        DiagnosticBundleBuilder.make(
            records: allRecords(),
            createdAt: clock.now()
        )
    }

    func enforceRetention() {
        let records = store.allRecords()
        let ids = DiagnosticRetention.recordIDsToDelete(records: records, now: clock.now())
        if !ids.isEmpty {
            store.delete(ids: ids)
        }
    }

    private func makeRecord(
        recordedAt: Date,
        code: DiagnosticEventCode,
        physicalKeyboardToken: TemporaryPhysicalKeyboardToken? = nil,
        sequenceNumber: UInt64? = nil,
        relativeMilliseconds: Int64? = nil,
        switchingStatus: SwitchingStatus? = nil
    ) -> DiagnosticRecord {
        let order = nextInsertionOrder
        nextInsertionOrder += 1
        return DiagnosticRecord(
            recordedAt: recordedAt,
            code: code,
            physicalKeyboardToken: physicalKeyboardToken,
            sequenceNumber: sequenceNumber,
            relativeMilliseconds: relativeMilliseconds,
            switchingStatus: switchingStatus,
            insertionOrder: order
        )
    }

    private func insertRecord(_ record: DiagnosticRecord) {
        store.insert(record)
        enforceRetention()
        onChange?()
    }

    private func scheduleSessionExpiry(from startedAt: Date) {
        cancelSessionExpiry()
        let remaining = DiagnosticDataPolicy.maximumSessionDuration
            - clock.now().timeIntervalSince(startedAt)
        guard remaining > 0 else {
            enforceSessionLimit()
            return
        }

        sessionExpiryTask = Task { @MainActor [weak self] in
            let nanos = UInt64(remaining * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            self?.enforceSessionLimit()
        }
    }

    private func cancelSessionExpiry() {
        sessionExpiryTask?.cancel()
        sessionExpiryTask = nil
    }
}
