import Foundation

struct PhysicalKeyboardIdentity: Hashable, Sendable {
    private enum HardwareAnchor: Hashable, Sendable {
        case builtIn
        case serialNumber(String)
        case bluetoothAddress(String)
        case vendorProduct(vendorID: UInt32, productID: UInt32)

        var rawValue: String {
            switch self {
            case .builtIn:
                "built-in"
            case let .serialNumber(value):
                "serial:\(value)"
            case let .bluetoothAddress(value):
                "bluetooth:\(value)"
            case let .vendorProduct(vendorID, productID):
                "hardware:\(vendorID):\(productID)"
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

    /// `rawValue` is CoreHID's unique ID. Built-in identities require it; the
    /// hardware-derived anchors do not.
    init?(
        rawValue: String?,
        isBuiltIn: Bool,
        serialNumber: String?,
        bluetoothAddress: String? = nil,
        vendorID: UInt32? = nil,
        productID: UInt32? = nil
    ) {
        let normalized = Self.normalizedHardwareToken(rawValue)

        if isBuiltIn {
            guard let normalized else {
                return nil
            }
            value = normalized
            hardwareAnchor = .builtIn
        } else if let serialNumber = Self.normalizedHardwareToken(serialNumber) {
            // Without a unique ID, the serial number alone names the device.
            value = normalized ?? "serial:\(serialNumber)"
            hardwareAnchor = .serialNumber(serialNumber)
        } else if let bluetoothAddress = Self.normalizedBluetoothAddress(bluetoothAddress) {
            // CoreHID unique IDs churn on BLE reconnect. Group by the MAC.
            value = "bluetooth:\(bluetoothAddress)"
            hardwareAnchor = .bluetoothAddress(bluetoothAddress)
        } else if let vendorID, let productID, vendorID != 0, productID != 0 {
            // No serial or address, such as a 2.4 GHz receiver. CoreHID unique
            // IDs differ per HID interface, so group every interface by model.
            let anchor = HardwareAnchor.vendorProduct(vendorID: vendorID, productID: productID)
            value = anchor.rawValue
            hardwareAnchor = anchor
        } else if let normalized {
            value = normalized
            hardwareAnchor = nil
        } else {
            return nil
        }
    }

    var isStable: Bool {
        hardwareAnchor != nil
    }

    var rawValue: String {
        "\(value)|anchor:\(hardwareAnchor?.rawValue ?? "unstable")"
    }

    var groupingKey: String {
        value
    }

    /// Whether the identity names a model rather than one device, so two
    /// identical devices connected at once share it.
    var isModelAnchored: Bool {
        if case .vendorProduct = hardwareAnchor {
            return true
        }
        return false
    }

    private static func normalizedHardwareToken(_ raw: String?) -> String? {
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }

    static func normalizedBluetoothAddress(_ raw: String?) -> String? {
        guard let raw else {
            return nil
        }

        let hex = raw.lowercased().filter(\.isHexDigit)
        guard hex.count == 12 else {
            return nil
        }
        return hex
    }

    /// Six-byte CoreHID `DeviceAddress` data as a normalized Bluetooth address.
    static func bluetoothAddress(fromAddressData data: Data) -> String? {
        guard data.count == 6 else {
            return nil
        }

        var hex = ""
        hex.reserveCapacity(12)
        for byte in data {
            hex.append(String(byte >> 4, radix: 16))
            hex.append(String(byte & 0x0F, radix: 16))
        }
        return normalizedBluetoothAddress(hex)
    }
}
