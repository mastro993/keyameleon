#if DEBUG
import Foundation

@MainActor
extension PreviewFixtures {
    static func seedDisconnectedRecord(
        into store: InMemoryPhysicalKeyboardRecordStore,
        state: PreviewSetupState
    ) {
        guard state == .mixedAssignments else {
            return
        }

        store.saveName(
            identityKey: stableRecordID(identity: "preview.disconnected"),
            productName: "HHKB Professional",
            customName: "Office Keyboard"
        )
        store.saveAssignment(
            identityKey: stableRecordID(identity: "preview.disconnected"),
            productName: "HHKB Professional",
            assignment: KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.German")
        )
    }

    static func hardwareFacts(
        for state: PreviewSetupState
    ) -> [PhysicalKeyboardHardwareFacts] {
        switch state {
        case .assignmentsPopulated, .readyPopulated, .readyPaused, .paused:
            return [
                makeFacts(
                    serviceID: 10,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 11,
                    identity: "preview.desk",
                    serial: "desk",
                    name: "HHKB Professional"
                )
            ]
        case .pencilAssignments, .menuAssignments:
            let facts = [
                PhysicalKeyboardHardwareFacts(
                    serviceID: 8,
                    identity: PhysicalKeyboardIdentity(
                        rawValue: "preview.macbook", isBuiltIn: true, serialNumber: nil
                    ),
                    name: "MacBook Keyboard",
                    transport: .usb,
                    isBuiltIn: true,
                    vendorID: 500,
                    productID: 100,
                    modelNumber: "MacBook",
                    serialNumber: nil
                ),
                makeFacts(
                    serviceID: 10, identity: "preview.travel", serial: "travel", name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 11, identity: "preview.desk", serial: "desk", name: "HHKB Professional"
                ),
                makeFacts(
                    serviceID: 12, identity: "preview.magic", serial: "magic", name: "Magic Keyboard"
                )
            ]
            return state == .menuAssignments ? facts.filter { $0.serviceID != 12 } : facts
        case .manyAssignments:
            return (1...6).map { index in
                makeFacts(
                    serviceID: UInt64(60 + index),
                    identity: "preview.board.\(index)",
                    serial: "board-\(index)",
                    name: "Board \(index)"
                )
            }
        case .mixedAssignments:
            return [
                makeFacts(
                    serviceID: 20,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 21,
                    identity: "preview.desk",
                    serial: "desk",
                    name: "HHKB Professional"
                ),
                makeFacts(
                    serviceID: 22,
                    identity: nil,
                    serial: nil,
                    name: "Unidentifiable Keyboard"
                )
            ]
        case .excludedDevices:
            return [
                makeFacts(
                    serviceID: 30,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 31,
                    identity: nil,
                    serial: nil,
                    name: "Logitech USB Receiver",
                    vendorID: 200
                )
            ]
        case .permissionRequired, .permissionDenied, .assignmentsEmpty, .readyEmpty, .persistenceFailure, .completed:
            return []
        }
    }

    static func configureAssignments(
        for model: SetupModel,
        state: PreviewSetupState
    ) {
        for keyboard in model.physicalKeyboards where keyboard.isAssignable {
            switch keyboard.productName {
            case "Keychron K2":
                model.setPhysicalKeyboardName(
                    keyboard.id,
                    customName: [.pencilAssignments, .menuAssignments].contains(state) ? "Office Keyboard" : "Travel"
                )
                model.setKeyboardAssignment(
                    keyboard.id,
                    inputSourceIdentifier: [.pencilAssignments, .menuAssignments].contains(state)
                        ? "com.apple.keylayout.US" : "com.apple.keylayout.Italian"
                )
            case "HHKB Professional":
                if [.pencilAssignments, .menuAssignments].contains(state) {
                    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel Keyboard")
                }
                if [.assignmentsPopulated, .paused, .pencilAssignments, .menuAssignments].contains(state) {
                    model.setKeyboardAssignment(
                        keyboard.id,
                        inputSourceIdentifier: [.pencilAssignments, .menuAssignments].contains(state)
                            ? "com.apple.keylayout.German" : "com.apple.keylayout.US"
                    )
                }
            case "MacBook Keyboard":
                model.setKeyboardAssignment(
                    keyboard.id, inputSourceIdentifier: "com.apple.keylayout.Italian"
                )
            case "Magic Keyboard":
                model.setKeyboardAssignment(
                    keyboard.id, inputSourceIdentifier: "com.apple.keylayout.US"
                )
            case "Unidentifiable Keyboard":
                break
            case let name where state == .manyAssignments && name.hasPrefix("Board "):
                model.setKeyboardAssignment(
                    keyboard.id,
                    inputSourceIdentifier: "com.apple.keylayout.Italian"
                )
            default:
                break
            }
        }

        if state == .mixedAssignments,
           let desk = model.physicalKeyboards.first(where: { $0.productName == "HHKB Professional" }) {
            model.setKeyboardAssignment(
                desk.id,
                inputSourceIdentifier: "com.apple.keylayout.Missing"
            )
        }
    }

    private static func makeFacts(
        serviceID: UInt64,
        identity: String?,
        serial: String?,
        name: String,
        vendorID: UInt32 = 42
    ) -> PhysicalKeyboardHardwareFacts {
        PhysicalKeyboardHardwareFacts(
            serviceID: serviceID,
            identity: identity.flatMap {
                PhysicalKeyboardIdentity(
                    rawValue: $0,
                    isBuiltIn: false,
                    serialNumber: serial
                )
            },
            name: name,
            transport: .usb,
            isBuiltIn: false,
            vendorID: vendorID,
            productID: 7,
            modelNumber: "Preview",
            serialNumber: serial
        )
    }

    private static func stableRecordID(identity: String) -> String {
        "identity:\(identity)|anchor:serial:\(identity)"
    }
}

#endif
