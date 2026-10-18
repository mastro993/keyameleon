import Foundation

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
