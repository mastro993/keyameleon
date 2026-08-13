import Foundation

enum PhysicalKeyboardTransport: Equatable, Sendable {
    case usb
    case bluetooth
    case bluetoothLowEnergy
    case other
}

struct PhysicalKeyboardIdentity: Hashable, Sendable {
    private enum HardwareAnchor: Hashable, Sendable {
        case builtIn
        case serialNumber(String)

        var rawValue: String {
            switch self {
            case .builtIn:
                "built-in"
            case let .serialNumber(value):
                "serial:\(value)"
            }
        }
    }

    private let value: String
    private let hardwareAnchor: HardwareAnchor?

    /// One local identity represents every built-in Physical Keyboard service.
    /// It does not contain CoreHID or Mac hardware identifiers.
    static let builtIn = PhysicalKeyboardIdentity(
        rawValue: "built-in",
        isBuiltIn: true,
        serialNumber: nil
    )!

    init?(rawValue: String, isBuiltIn: Bool, serialNumber: String?) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        value = normalized
        if isBuiltIn {
            hardwareAnchor = .builtIn
        } else if let serialNumber = serialNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !serialNumber.isEmpty
        {
            hardwareAnchor = .serialNumber(serialNumber)
        } else {
            hardwareAnchor = nil
        }
    }

    var isStable: Bool {
        hardwareAnchor != nil
    }

    fileprivate var rawValue: String {
        "\(value)|anchor:\(hardwareAnchor?.rawValue ?? "unstable")"
    }

    fileprivate var groupingKey: String {
        value
    }
}

enum PhysicalKeyboardIdentityStability: Equatable, Sendable {
    case stable
    case unstable
}

enum PhysicalKeyboardUnsupportedReason: Equatable, Sendable {
    case missingIdentity
    case unstableIdentity
    case sharedIdentity
    case ambiguousIdentity
}

struct KeyboardAssignment: Equatable, Sendable {
    let inputSourceIdentifier: String

    init?(inputSourceIdentifier: String) {
        let normalized = inputSourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        self.inputSourceIdentifier = normalized
    }
}

enum PhysicalKeyboardAssignmentState: Equatable, Sendable {
    case unassigned
    case assigned(KeyboardAssignment)
    case unsupported(PhysicalKeyboardUnsupportedReason)
}

struct PhysicalKeyboardHardwareFacts: Equatable, Sendable {
    let serviceID: UInt64
    let identity: PhysicalKeyboardIdentity?
    let identityStability: PhysicalKeyboardIdentityStability
    let name: String?
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
    let vendorID: UInt32
    let productID: UInt32
    let modelNumber: String?
    let serialNumber: String?

    init(
        serviceID: UInt64,
        identity: PhysicalKeyboardIdentity?,
        name: String?,
        transport: PhysicalKeyboardTransport,
        isBuiltIn: Bool,
        vendorID: UInt32,
        productID: UInt32,
        modelNumber: String?,
        serialNumber: String?
    ) {
        self.serviceID = serviceID
        self.identity = identity
        self.identityStability = identity?.isStable == true ? .stable : .unstable
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.transport = transport
        self.isBuiltIn = isBuiltIn
        self.vendorID = vendorID
        self.productID = productID
        self.modelNumber = modelNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.serialNumber = serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    fileprivate var stableFacts: StablePhysicalKeyboardFacts {
        StablePhysicalKeyboardFacts(
            vendorID: vendorID,
            productID: productID,
            modelNumber: modelNumber,
            serialNumber: serialNumber,
            transport: transport,
            isBuiltIn: isBuiltIn
        )
    }

}

enum PhysicalKeyboardDiscoveryChange: Sendable {
    case connected(PhysicalKeyboardHardwareFacts)
    case disconnected(serviceID: UInt64)
}

struct PhysicalKeyboardRecordID: Hashable, Sendable {
    let rawValue: String

    static let builtIn = PhysicalKeyboardRecordID(
        rawValue: "identity:\(PhysicalKeyboardIdentity.builtIn.rawValue)"
    )

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var isIdentityBased: Bool {
        rawValue.hasPrefix("identity:")
    }

    var isFixedBuiltInIdentity: Bool {
        self == .builtIn
    }
}

enum PhysicalKeyboardConnectionState: Equatable, Sendable {
    case connected
    case disconnected
}

struct SavedPhysicalKeyboardRecord: Equatable, Sendable {
    let identityKey: String
    let productName: String
    let customName: String?
    let keyboardAssignment: KeyboardAssignment?

    init(
        identityKey: String,
        productName: String,
        customName: String? = nil,
        keyboardAssignment: KeyboardAssignment? = nil
    ) {
        self.identityKey = identityKey
        self.productName = productName
        self.customName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.keyboardAssignment = keyboardAssignment
    }

    var name: String {
        customName ?? productName
    }

    var recordID: PhysicalKeyboardRecordID {
        PhysicalKeyboardRecordID(rawValue: identityKey)
    }

    var isBuiltInIdentity: Bool {
        identityKey == PhysicalKeyboardRecordID.builtIn.rawValue
            || identityKey.contains("|anchor:built-in")
    }
}

struct PhysicalKeyboard: Identifiable, Equatable, Sendable {
    let id: PhysicalKeyboardRecordID
    let productName: String
    let customName: String?
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
    let assignmentState: PhysicalKeyboardAssignmentState
    let connectedServiceCount: Int
    let connectionState: PhysicalKeyboardConnectionState
    let isActive: Bool

    var name: String {
        customName ?? productName
    }

    var keyboardAssignment: KeyboardAssignment? {
        if case let .assigned(assignment) = assignmentState {
            return assignment
        }

        return nil
    }

    var isAssignable: Bool {
        switch assignmentState {
        case .unassigned, .assigned:
            true
        case .unsupported:
            false
        }
    }

    func applying(savedRecord: SavedPhysicalKeyboardRecord?) -> PhysicalKeyboard {
        guard isAssignable, let savedRecord else {
            return self
        }

        let assignmentState: PhysicalKeyboardAssignmentState =
            if let assignment = savedRecord.keyboardAssignment {
                .assigned(assignment)
            } else {
                .unassigned
            }

        return PhysicalKeyboard(
            id: id,
            productName: productName,
            customName: savedRecord.customName,
            transport: transport,
            isBuiltIn: isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: connectedServiceCount,
            connectionState: connectionState,
            isActive: isActive
        )
    }

    /// Elevates unsupported identity groups after authentic Manual Physical Keyboard Designation.
    func elevatingWithManualDesignation(confirmedName: String) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: id,
            productName: productName,
            customName: confirmedName,
            transport: transport,
            isBuiltIn: isBuiltIn,
            assignmentState: .unassigned,
            connectedServiceCount: connectedServiceCount,
            connectionState: connectionState,
            isActive: isActive
        )
    }

    func markingActive(_ isActive: Bool) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: id,
            productName: productName,
            customName: customName,
            transport: transport,
            isBuiltIn: isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: connectedServiceCount,
            connectionState: connectionState,
            isActive: isActive
        )
    }

    func asDisconnected() -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: id,
            productName: productName,
            customName: customName,
            transport: transport,
            isBuiltIn: isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: 0,
            connectionState: .disconnected,
            isActive: isActive
        )
    }

    static func disconnected(from savedRecord: SavedPhysicalKeyboardRecord) -> PhysicalKeyboard {
        let assignmentState: PhysicalKeyboardAssignmentState =
            if let assignment = savedRecord.keyboardAssignment {
                .assigned(assignment)
            } else {
                .unassigned
            }

        return PhysicalKeyboard(
            id: savedRecord.recordID,
            productName: savedRecord.productName,
            customName: savedRecord.customName,
            transport: .other,
            isBuiltIn: savedRecord.isBuiltInIdentity,
            assignmentState: assignmentState,
            connectedServiceCount: 0,
            connectionState: .disconnected,
            isActive: false
        )
    }
}

enum PhysicalKeyboardListOrdering {
    static func sorted(
        _ physicalKeyboards: [PhysicalKeyboard],
        activeID: PhysicalKeyboardRecordID?
    ) -> [PhysicalKeyboard] {
        physicalKeyboards.sorted { left, right in
            let leftRank = sortRank(for: left, activeID: activeID)
            let rightRank = sortRank(for: right, activeID: activeID)
            if leftRank != rightRank {
                return leftRank < rightRank
            }

            let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.rawValue < right.id.rawValue
        }
    }

    private static func sortRank(
        for physicalKeyboard: PhysicalKeyboard,
        activeID: PhysicalKeyboardRecordID?
    ) -> Int {
        if let activeID, physicalKeyboard.id == activeID {
            return 0
        }

        switch physicalKeyboard.connectionState {
        case .connected:
            return 1
        case .disconnected:
            return 2
        }
    }
}

struct PhysicalKeyboardCatalog: Sendable {
    private var services: [UInt64: PhysicalKeyboardHardwareFacts] = [:]
    private var serviceToRecordID: [UInt64: PhysicalKeyboardRecordID] = [:]
    private(set) var physicalKeyboards: [PhysicalKeyboard] = []

    mutating func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        switch change {
        case let .connected(facts):
            services[facts.serviceID] = facts
        case let .disconnected(serviceID):
            services.removeValue(forKey: serviceID)
        }

        rebuild()
    }

    func physicalKeyboard(forServiceID serviceID: UInt64) -> PhysicalKeyboard? {
        guard let recordID = serviceToRecordID[serviceID] else {
            return nil
        }

        return physicalKeyboards.first { $0.id == recordID }
    }

    private mutating func rebuild() {
        let records = makePhysicalKeyboards(from: services.values)
        physicalKeyboards = records.records
        serviceToRecordID = records.serviceToRecordID
    }

    private func makePhysicalKeyboards(
        from services: Dictionary<UInt64, PhysicalKeyboardHardwareFacts>.Values
    ) -> (records: [PhysicalKeyboard], serviceToRecordID: [UInt64: PhysicalKeyboardRecordID]) {
        var serviceToRecordID: [UInt64: PhysicalKeyboardRecordID] = [:]

        let builtInServices = services.filter(\.isBuiltIn)
        let externalServices = services.filter { !$0.isBuiltIn }

        var builtInRecords: [PhysicalKeyboard] = []
        if !builtInServices.isEmpty {
            let builtInRecord = makeBuiltInRecord(for: Array(builtInServices))
            for facts in builtInServices {
                serviceToRecordID[facts.serviceID] = builtInRecord.id
            }
            builtInRecords.append(builtInRecord)
        }

        let missingIdentityRecords = externalServices
            .filter { $0.identity == nil }
            .map { facts -> PhysicalKeyboard in
                let record = makeUnsupportedRecord(for: [facts], reason: .missingIdentity)
                serviceToRecordID[facts.serviceID] = record.id
                return record
            }

        let identityGroups = Dictionary(grouping: externalServices.compactMap { facts in
            facts.identity == nil ? nil : facts
        }, by: { $0.identity!.groupingKey })

        let identityRecords = identityGroups.values.map { group -> PhysicalKeyboard in
            let record = makeIdentityRecord(for: Array(group))
            for facts in group {
                serviceToRecordID[facts.serviceID] = record.id
            }
            return record
        }

        let records = (builtInRecords + missingIdentityRecords + identityRecords).sorted { left, right in
            let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.rawValue < right.id.rawValue
        }

        return (records, serviceToRecordID)
    }

    private func makeBuiltInRecord(
        for group: [PhysicalKeyboardHardwareFacts]
    ) -> PhysicalKeyboard {
        let sortedGroup = group.sorted { $0.serviceID < $1.serviceID }
        let sharedProductName: String? = if let firstName = sortedGroup.first?.name,
                                            sortedGroup.allSatisfy({ $0.name == firstName })
        {
            firstName
        } else {
            nil
        }
        let productName = sharedProductName ?? "Built-in Keyboard"

        return makeRecord(
            for: sortedGroup,
            identity: .builtIn,
            assignmentState: .unassigned,
            productName: productName
        )
    }

    private func makeIdentityRecord(
        for group: [PhysicalKeyboardHardwareFacts]
    ) -> PhysicalKeyboard {
        let sortedGroup = group.sorted { $0.serviceID < $1.serviceID }
        let representative = sortedGroup[0]
        let identity = representative.identity!

        let reason: PhysicalKeyboardUnsupportedReason? = {
            guard sortedGroup.allSatisfy({ $0.identityStability == .stable }) else {
                return .unstableIdentity
            }

            let serialNumbers = Set(sortedGroup.compactMap(\.serialNumber))
            if serialNumbers.count > 1 {
                return .sharedIdentity
            }

            let stableFacts = Set(sortedGroup.map(\.stableFacts))
            return stableFacts.count > 1 ? .ambiguousIdentity : nil
        }()

        if let reason {
            return makeUnsupportedRecord(for: sortedGroup, reason: reason, identity: identity)
        }

        return makeRecord(
            for: sortedGroup,
            identity: identity,
            assignmentState: .unassigned
        )
    }

    private func makeUnsupportedRecord(
        for group: [PhysicalKeyboardHardwareFacts],
        reason: PhysicalKeyboardUnsupportedReason,
        identity: PhysicalKeyboardIdentity? = nil
    ) -> PhysicalKeyboard {
        makeRecord(
            for: group,
            identity: identity,
            assignmentState: .unsupported(reason)
        )
    }

    private func makeRecord(
        for group: [PhysicalKeyboardHardwareFacts],
        identity: PhysicalKeyboardIdentity?,
        assignmentState: PhysicalKeyboardAssignmentState,
        productName: String? = nil
    ) -> PhysicalKeyboard {
        let representative = group.sorted { $0.serviceID < $1.serviceID }[0]
        let recordID = if let identity {
            PhysicalKeyboardRecordID(rawValue: "identity:\(identity.rawValue)")
        } else {
            PhysicalKeyboardRecordID(rawValue: "service:\(representative.serviceID)")
        }

        return PhysicalKeyboard(
            id: recordID,
            productName: productName ?? representative.name ?? "Physical Keyboard",
            customName: nil,
            transport: representative.transport,
            isBuiltIn: representative.isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: group.count,
            connectionState: .connected,
            isActive: false
        )
    }
}

private struct StablePhysicalKeyboardFacts: Hashable, Sendable {
    let vendorID: UInt32
    let productID: UInt32
    let modelNumber: String?
    let serialNumber: String?
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
