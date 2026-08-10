import Foundation

enum PhysicalKeyboardTransport: Equatable, Sendable {
    case usb
    case bluetooth
    case bluetoothLowEnergy
    case other

    var displayName: String {
        switch self {
        case .usb:
            "USB"
        case .bluetooth:
            "Bluetooth"
        case .bluetoothLowEnergy:
            "Bluetooth Low Energy"
        case .other:
            "Other"
        }
    }
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

    var displayName: String {
        switch self {
        case .missingIdentity:
            "Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Physical Keyboard Identity ambiguous"
        }
    }
}

enum PhysicalKeyboardAssignmentState: Equatable, Sendable {
    case unassigned
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
    fileprivate let rawValue: String

    fileprivate init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct PhysicalKeyboard: Identifiable, Equatable, Sendable {
    let id: PhysicalKeyboardRecordID
    let name: String
    let transport: PhysicalKeyboardTransport
    let isBuiltIn: Bool
    let assignmentState: PhysicalKeyboardAssignmentState
    let connectedServiceCount: Int

    var isAssignable: Bool {
        if case .unassigned = assignmentState {
            return true
        }

        return false
    }

    var statusDescription: String {
        switch assignmentState {
        case .unassigned:
            "Unassigned"
        case let .unsupported(reason):
            "Unsupported — \(reason.displayName)"
        }
    }
}

struct PhysicalKeyboardCatalog: Sendable {
    private var services: [UInt64: PhysicalKeyboardHardwareFacts] = [:]
    private(set) var physicalKeyboards: [PhysicalKeyboard] = []

    mutating func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        switch change {
        case let .connected(facts):
            services[facts.serviceID] = facts
        case let .disconnected(serviceID):
            services.removeValue(forKey: serviceID)
        }

        physicalKeyboards = makePhysicalKeyboards(from: services.values)
    }

    private func makePhysicalKeyboards(
        from services: Dictionary<UInt64, PhysicalKeyboardHardwareFacts>.Values
    ) -> [PhysicalKeyboard] {
        let missingIdentityRecords = services
            .filter { $0.identity == nil }
            .map { makeUnsupportedRecord(for: [$0], reason: .missingIdentity) }

        let identityGroups = Dictionary(grouping: services.compactMap { facts in
            facts.identity == nil ? nil : facts
        }, by: { $0.identity!.groupingKey })

        let identityRecords = identityGroups.values.map { group in
            makeIdentityRecord(for: Array(group))
        }

        return (missingIdentityRecords + identityRecords).sorted { left, right in
            let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.rawValue < right.id.rawValue
        }
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
        assignmentState: PhysicalKeyboardAssignmentState
    ) -> PhysicalKeyboard {
        let representative = group.sorted { $0.serviceID < $1.serviceID }[0]
        let recordID = if let identity {
            PhysicalKeyboardRecordID(rawValue: "identity:\(identity.rawValue)")
        } else {
            PhysicalKeyboardRecordID(rawValue: "service:\(representative.serviceID)")
        }

        return PhysicalKeyboard(
            id: recordID,
            name: representative.name ?? "Physical Keyboard",
            transport: representative.transport,
            isBuiltIn: representative.isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: group.count
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
