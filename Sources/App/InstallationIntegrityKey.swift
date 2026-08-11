import CryptoKit
import Foundation
import Security

@MainActor
protocol InstallationIntegrityKeyProviding: AnyObject {
    func integrityKey() -> SymmetricKey
}

/// In-memory integrity key for tests.
@MainActor
final class InMemoryInstallationIntegrityKeyProvider: InstallationIntegrityKeyProviding {
    private let key: SymmetricKey

    init(key: SymmetricKey = SymmetricKey(size: .bits256)) {
        self.key = key
    }

    func integrityKey() -> SymmetricKey {
        key
    }
}

/// Installation integrity key for Manual Physical Keyboard Designation. Lives in Keychain only.
@MainActor
final class KeychainInstallationIntegrityKeyProvider: InstallationIntegrityKeyProviding {
    private enum Constants {
        static let service = "dev.fedemas.keyameleon.installation-integrity"
        static let account = "manual-physical-keyboard-designation"
    }

    private var cachedKey: SymmetricKey?

    func integrityKey() -> SymmetricKey {
        if let cachedKey {
            return cachedKey
        }

        if let existing = loadKey() {
            cachedKey = existing
            return existing
        }

        let generated = SymmetricKey(size: .bits256)
        store(generated)
        cachedKey = generated
        return generated
    }

    private func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data, !data.isEmpty else {
            fatalError("Keychain load failed for installation integrity key: \(status)")
        }

        return SymmetricKey(data: data)
    }

    private func store(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.account,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            fatalError("Keychain store failed for installation integrity key: \(status)")
        }
    }
}
