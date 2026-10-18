import Foundation

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

    /// Connection type a person recognizes, such as `USB` or `Built-in`.
    var connectionTypeName: String {
        if isBuiltIn {
            return String(localized: .connectionTypeBuiltIn)
        }

        return switch transport {
        case .usb: "USB"
        case .bluetooth: "Bluetooth"
        case .bluetoothLowEnergy: "Bluetooth Low Energy"
        case .other: String(localized: .connectionTypeOther)
        }
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

    static func restored(from savedRecord: SavedPhysicalKeyboardRecord) -> PhysicalKeyboard {
        let assignmentState: PhysicalKeyboardAssignmentState =
            if let assignment = savedRecord.keyboardAssignment {
                .assigned(assignment)
            } else {
                .unassigned
            }
        let isBuiltIn = savedRecord.isBuiltInIdentity

        return PhysicalKeyboard(
            id: savedRecord.recordID,
            productName: savedRecord.productName,
            customName: savedRecord.customName,
            transport: .other,
            isBuiltIn: isBuiltIn,
            assignmentState: assignmentState,
            connectedServiceCount: isBuiltIn ? 1 : 0,
            connectionState: isBuiltIn ? .connected : .disconnected,
            isActive: false
        )
    }
}
