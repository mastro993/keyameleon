import Foundation

/// Saved user decision that one physical input device is not a Physical Keyboard.
struct SavedPhysicalKeyboardExclusion: Codable, Equatable, Sendable {
    /// Key of the excluded device, in the `PhysicalKeyboardExclusionKey` space.
    let key: String
    /// Physical Keyboard Name at the moment of exclusion. The restore list reads it
    /// while the device is disconnected, so it never consults the device again.
    let name: String
}

/// Keys that identify one physical input device for Physical Keyboard Exclusion.
///
/// One key covers every CoreHID service of one device and survives a reconnect,
/// so a saved exclusion keeps matching after the device leaves and returns.
enum PhysicalKeyboardExclusionKey {
    /// Key of a record ID. The identity anchor is dropped, so services of one
    /// device agree even when their anchors differ.
    static func key(for recordID: PhysicalKeyboardRecordID) -> String {
        guard let anchorRange = recordID.rawValue.range(of: "|anchor:") else {
            return recordID.rawValue
        }

        return String(recordID.rawValue[recordID.rawValue.startIndex..<anchorRange.lowerBound])
    }

    /// Key of one discovered HID service, or nil when the device is not excludable.
    ///
    /// The built-in Physical Keyboard takes the nil branch and stays unexcludable.
    /// A device without a stable Physical Keyboard Identity keys by its hardware
    /// facts, because its `service:<serviceID>` record ID changes on reconnect.
    static func key(for facts: PhysicalKeyboardHardwareFacts) -> String? {
        guard !facts.isBuiltIn else {
            return nil
        }

        guard let identity = facts.identity else {
            return "hardware:\(facts.vendorID):\(facts.productID):\(facts.modelNumber ?? "-")"
        }

        return "identity:\(identity.groupingKey)"
    }
}
