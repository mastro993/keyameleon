import CryptoKit
import Foundation

/// Closed Diagnostic Data categories. No free-form category strings.
enum DiagnosticCategory: String, Equatable, Sendable, CaseIterable {
    case operationalError
    case operationalStateChange
    case observationOrder
    case inputSourceSelectionResult
    case sessionLifecycle
}

/// Closed Diagnostic Data event codes. No free-form message strings.
enum DiagnosticEventCode: String, Equatable, Sendable, CaseIterable {
    // Operational errors (default recording)
    case inputSourceSelectionFailed
    case inputSourceVerificationFailed
    case discoveryFailed
    case permissionDenied

    // Operational state changes (default recording)
    case switchingStatusChanged
    case physicalKeyboardConnected
    case physicalKeyboardDisconnected
    case activePhysicalKeyboardChanged
    case assignmentSaved
    case assignmentRemoved

    // Input Source selection results (Diagnostic Session only)
    case inputSourceSelectionSucceeded
    case inputSourceSelectionCoalesced

    // Observation order markers (Diagnostic Session only)
    case activationActivityAttributed

    // Session lifecycle
    case diagnosticSessionStarted
    case diagnosticSessionStopped
    case diagnosticSessionExpired
}

enum DiagnosticRecordingMode: Equatable, Sendable {
    /// Bounded operational errors and state changes only.
    case defaultMode
    /// Detailed allowlisted Diagnostic Data during a Diagnostic Session.
    case diagnosticSession
}

enum DiagnosticDataPolicy {
    static let maximumSessionDuration: TimeInterval = 10 * 60
    static let maximumRetentionAge: TimeInterval = 7 * 24 * 60 * 60
    static let maximumByteCount = 5 * 1024 * 1024

    /// Fixed estimate for retention size accounting (closed schema, no free-form payload).
    static let estimatedBytesPerRecord = 256

    static func category(for code: DiagnosticEventCode) -> DiagnosticCategory {
        switch code {
        case .inputSourceSelectionFailed,
             .inputSourceVerificationFailed,
             .discoveryFailed,
             .permissionDenied:
            .operationalError
        case .switchingStatusChanged,
             .physicalKeyboardConnected,
             .physicalKeyboardDisconnected,
             .activePhysicalKeyboardChanged,
             .assignmentSaved,
             .assignmentRemoved:
            .operationalStateChange
        case .inputSourceSelectionSucceeded,
             .inputSourceSelectionCoalesced:
            .inputSourceSelectionResult
        case .activationActivityAttributed:
            .observationOrder
        case .diagnosticSessionStarted,
             .diagnosticSessionStopped,
             .diagnosticSessionExpired:
            .sessionLifecycle
        }
    }

    /// Default mode records operational errors and state changes only.
    /// Diagnostic Session also allows detailed allowlisted categories.
    static func isAllowed(_ code: DiagnosticEventCode, mode: DiagnosticRecordingMode) -> Bool {
        switch category(for: code) {
        case .operationalError, .operationalStateChange, .sessionLifecycle:
            true
        case .observationOrder, .inputSourceSelectionResult:
            mode == .diagnosticSession
        }
    }

    static func estimatedByteCount(forRecordCount count: Int) -> Int {
        max(0, count) * estimatedBytesPerRecord
    }
}

/// Temporary random token for a Physical Keyboard in Diagnostic Data.
/// Never an exact Physical Keyboard Identity, serial, or custom name.
struct TemporaryPhysicalKeyboardToken: Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// One-way linkage key for Forget → Diagnostic Data deletion.
/// Stores a SHA-256 digest of the product identity key — never the identity itself.
struct DiagnosticIdentityLinkageKey: Hashable, Sendable {
    let rawValue: String

    init(identityKey: String) {
        let digest = SHA256.hash(data: Data(identityKey.utf8))
        rawValue = digest.map { String(format: "%02x", $0) }.joined()
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Closed allowlist Diagnostic Data record. Fields are typed enums/scalars only.
struct DiagnosticRecord: Equatable, Identifiable, Sendable {
    let id: UUID
    let recordedAt: Date
    let category: DiagnosticCategory
    let code: DiagnosticEventCode
    let physicalKeyboardToken: TemporaryPhysicalKeyboardToken?
    /// Observation order within an active Diagnostic Session.
    let sequenceNumber: UInt64?
    /// Milliseconds from Diagnostic Session start when recorded during a session.
    let relativeMilliseconds: Int64?
    /// Only `SwitchingStatus.rawValue` values are allowed.
    let switchingStatus: SwitchingStatus?
    /// Global insert order for stable oldest-first retention and reads.
    let insertionOrder: UInt64

    var estimatedByteCount: Int {
        DiagnosticDataPolicy.estimatedBytesPerRecord
    }

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        code: DiagnosticEventCode,
        physicalKeyboardToken: TemporaryPhysicalKeyboardToken? = nil,
        sequenceNumber: UInt64? = nil,
        relativeMilliseconds: Int64? = nil,
        switchingStatus: SwitchingStatus? = nil,
        insertionOrder: UInt64 = 0
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.category = DiagnosticDataPolicy.category(for: code)
        self.code = code
        self.physicalKeyboardToken = physicalKeyboardToken
        self.sequenceNumber = sequenceNumber
        self.relativeMilliseconds = relativeMilliseconds
        self.switchingStatus = switchingStatus
        self.insertionOrder = insertionOrder
    }
}

enum DiagnosticRetention {
    /// Returns record IDs to delete: age first, then oldest-first until under size cap.
    static func recordIDsToDelete(
        records: [DiagnosticRecord],
        now: Date,
        maximumAge: TimeInterval = DiagnosticDataPolicy.maximumRetentionAge,
        maximumByteCount: Int = DiagnosticDataPolicy.maximumByteCount
    ) -> [UUID] {
        let ageCutoff = now.addingTimeInterval(-maximumAge)
        var remaining = records.sorted(by: DiagnosticRecord.oldestFirst)
        var deleteIDs: [UUID] = []

        let expired = remaining.filter { $0.recordedAt < ageCutoff }
        deleteIDs.append(contentsOf: expired.map(\.id))
        remaining.removeAll { $0.recordedAt < ageCutoff }

        var byteCount = DiagnosticDataPolicy.estimatedByteCount(forRecordCount: remaining.count)
        while byteCount > maximumByteCount, let oldest = remaining.first {
            deleteIDs.append(oldest.id)
            remaining.removeFirst()
            byteCount = DiagnosticDataPolicy.estimatedByteCount(forRecordCount: remaining.count)
        }

        return deleteIDs
    }
}

extension DiagnosticRecord {
    static func oldestFirst(_ left: DiagnosticRecord, _ right: DiagnosticRecord) -> Bool {
        if left.recordedAt != right.recordedAt {
            return left.recordedAt < right.recordedAt
        }
        if left.insertionOrder != right.insertionOrder {
            return left.insertionOrder < right.insertionOrder
        }
        return left.id.uuidString < right.id.uuidString
    }
}

enum DiagnosticSessionTiming {
    static func isExpired(
        startedAt: Date,
        now: Date,
        maximumDuration: TimeInterval = DiagnosticDataPolicy.maximumSessionDuration
    ) -> Bool {
        now.timeIntervalSince(startedAt) >= maximumDuration
    }

    static func relativeMilliseconds(startedAt: Date, now: Date) -> Int64 {
        Int64((now.timeIntervalSince(startedAt) * 1_000).rounded())
    }
}

/// Sensitive value classes that must never appear in Diagnostic Data.
enum DiagnosticDataExclusion {
    static let forbiddenFieldLabels: [String] = [
        "Physical Keyboard Identity",
        "serial number",
        "location identifier",
        "custom Physical Keyboard Name",
        "Keyboard Assignment",
        "Input Source name",
        "Input Source identifier",
        "path",
        "user name",
        "application name",
        "macOS crash report",
        "Key Content",
    ]
}

struct DiagnosticBundleDateRange: Equatable, Sendable {
    let start: Date
    let end: Date
}

struct DiagnosticBundleSummary: Equatable, Sendable {
    let includedCategories: [DiagnosticCategory]
    let excludedSensitiveData: [String]
    let dateRange: DiagnosticBundleDateRange?
    let recordCount: Int
    let byteCount: Int
}

struct DiagnosticBundle: Equatable, Sendable {
    let data: Data
    let summary: DiagnosticBundleSummary
}

enum DiagnosticBundleBuilder {
    private static let formatVersion = 1

    static func make(records: [DiagnosticRecord], createdAt: Date) -> DiagnosticBundle {
        let orderedRecords = records.sorted(by: DiagnosticRecord.oldestFirst)
        let payload = Payload(
            formatVersion: formatVersion,
            createdAt: createdAt,
            records: orderedRecords.map(ExportRecord.init)
        )
        let data = encode(payload)
        let includedCategories = DiagnosticCategory.allCases.filter { category in
            orderedRecords.contains { $0.category == category }
        }
        let dateRange = orderedRecords.first.map { first in
            DiagnosticBundleDateRange(
                start: first.recordedAt,
                end: orderedRecords.last?.recordedAt ?? first.recordedAt
            )
        }

        return DiagnosticBundle(
            data: data,
            summary: DiagnosticBundleSummary(
                includedCategories: includedCategories,
                excludedSensitiveData: DiagnosticDataExclusion.forbiddenFieldLabels,
                dateRange: dateRange,
                recordCount: orderedRecords.count,
                byteCount: data.count
            )
        )
    }

    private static func encode(_ payload: Payload) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(payload)
        } catch {
            fatalError("Diagnostic Bundle encoding failed: \(error)")
        }
    }

    private struct Payload: Encodable {
        let formatVersion: Int
        let createdAt: Date
        let records: [ExportRecord]
    }

    private struct ExportRecord: Encodable {
        let recordedAt: Date
        let category: String
        let code: String
        let temporaryPhysicalKeyboardToken: String?
        let sequenceNumber: UInt64?
        let relativeMilliseconds: Int64?
        let switchingStatus: String?

        init(record: DiagnosticRecord) {
            recordedAt = record.recordedAt
            category = record.category.rawValue
            code = record.code.rawValue
            temporaryPhysicalKeyboardToken = record.physicalKeyboardToken?.rawValue.uuidString
            sequenceNumber = record.sequenceNumber
            relativeMilliseconds = record.relativeMilliseconds
            switchingStatus = record.switchingStatus?.rawValue
        }
    }
}
