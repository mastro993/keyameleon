import Foundation

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
}
