import Foundation

struct PhysicalKeyboardCatalog: Sendable {
    private var services: [UInt64: PhysicalKeyboardHardwareFacts] = [:]
    private var serviceToRecordID: [UInt64: PhysicalKeyboardRecordID] = [:]
    private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    private var excludedKeys: Set<String> = []

    var connectedExcludedKeys: Set<String> {
        Set(services.values.compactMap(PhysicalKeyboardExclusionKey.key(for:)))
            .intersection(excludedKeys)
    }

    mutating func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        switch change {
        case let .connected(facts):
            services[facts.serviceID] = facts
        case let .disconnected(serviceID):
            services.removeValue(forKey: serviceID)
        }

        rebuild()
    }

    /// Exclusion is saved user state, not discovered state, so the facts stay for
    /// the whole session: restoring a connected device needs no reconnect.
    ///
    /// Returns whether the set changed, so a caller publishes only on a real change.
    @discardableResult
    mutating func setExcludedKeys(_ keys: Set<String>) -> Bool {
        guard excludedKeys != keys else {
            return false
        }

        excludedKeys = keys
        rebuild()
        return true
    }

    mutating func removeAllServices() {
        services.removeAll()
        rebuild()
    }

    /// Key a person excludes this Physical Keyboard by, or nil when it cannot be
    /// excluded, which is the built-in Physical Keyboard.
    func exclusionKey(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String? {
        guard let serviceID = serviceToRecordID
            .first(where: { $0.value == physicalKeyboardID })?
            .key
        else {
            return nil
        }

        return services[serviceID].flatMap(PhysicalKeyboardExclusionKey.key(for:))
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

        let visibleServices = services.filter { facts in
            guard let key = PhysicalKeyboardExclusionKey.key(for: facts) else {
                return true
            }

            return !excludedKeys.contains(key)
        }
        let builtInServices = visibleServices.filter(\.isBuiltIn)
        let externalServices = visibleServices.filter { !$0.isBuiltIn }

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

        let identifiedServices = externalServices.compactMap { facts in
            facts.identity.map { identity in
                (facts: facts, groupingKey: identity.groupingKey)
            }
        }
        let identityGroups = Dictionary(grouping: identifiedServices, by: \.groupingKey)

        let identityRecords = identityGroups.values.map { group -> PhysicalKeyboard in
            let facts = group.map(\.facts)
            let record = makeIdentityRecord(for: facts)
            for item in facts {
                serviceToRecordID[item.serviceID] = record.id
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
                                            sortedGroup.allSatisfy({ $0.name == firstName }) {
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

            // Two identical devices without serial numbers sit on different ports.
            if identity.isModelAnchored,
               Set(sortedGroup.compactMap(\.locationID)).count > 1 {
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
