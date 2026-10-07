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

/// Keychain queries for the installation integrity key.
///
/// On macOS `kSecAttrAccessible` applies only to items in the data-protection
/// keychain, so every query that keeps the key on this device sets
/// `kSecUseDataProtectionKeychain`. The legacy queries match the login-keychain
/// item written before that flag existed; they are read and deleted once, when
/// the key is migrated.
enum InstallationIntegrityKeyQuery {
    static let service = "dev.fedemas.keyameleon.installation-integrity"
    static let account = "manual-physical-keyboard-designation"

    static func dataProtectionCopy() -> [String: Any] {
        var query = dataProtectionMatch
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    static func dataProtectionAdd(data: Data) -> [String: Any] {
        var query = dataProtectionMatch
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return query
    }

    static func dataProtectionDelete() -> [String: Any] {
        dataProtectionMatch
    }

    static func legacyCopy() -> [String: Any] {
        var query = legacyMatch
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    static func legacyDelete() -> [String: Any] {
        legacyMatch
    }

    private static var dataProtectionMatch: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false
        ]
    }

    private static var legacyMatch: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum InstallationIntegrityKeyMigrationStep: Equatable {
    case useDataProtectionItem
    case migrateLegacyItem
    case generateNew
}

enum InstallationIntegrityKeyMigration {
    static func step(
        dataProtectionItemFound: Bool,
        legacyItemFound: Bool
    ) -> InstallationIntegrityKeyMigrationStep {
        if dataProtectionItemFound { return .useDataProtectionItem }
        if legacyItemFound { return .migrateLegacyItem }
        return .generateNew
    }
}

/// Installation integrity key for Manual Physical Keyboard Designation. Lives in Keychain only.
@MainActor
final class KeychainInstallationIntegrityKeyProvider: InstallationIntegrityKeyProviding {
    private var cachedKey: SymmetricKey?

    func integrityKey() -> SymmetricKey {
        if let cachedKey {
            return cachedKey
        }

        if let existing = loadKey(InstallationIntegrityKeyQuery.dataProtectionCopy()) {
            cachedKey = existing
            return existing
        }

        let legacyKey = loadKey(InstallationIntegrityKeyQuery.legacyCopy())
        let key: SymmetricKey
        switch InstallationIntegrityKeyMigration.step(
            dataProtectionItemFound: false,
            legacyItemFound: legacyKey != nil
        ) {
        case .useDataProtectionItem:
            // The data-protection copy above already returned that item.
            fatalError("Installation integrity key: data-protection item reported missing then present.")
        case .migrateLegacyItem:
            guard let legacyKey else {
                fatalError("Installation integrity key: legacy item disappeared before migration.")
            }
            key = migrateToDataProtectionKeychain(legacyKey)
        case .generateNew:
            key = generateDataProtectionItem()
        }

        cachedKey = key
        return key
    }

    private func loadKey(_ query: [String: Any]) -> SymmetricKey? {
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

    /// Copies the legacy key into the data-protection keychain, then removes the legacy item.
    private func migrateToDataProtectionKeychain(_ key: SymmetricKey) -> SymmetricKey {
        let data = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd(InstallationIntegrityKeyQuery.dataProtectionAdd(data: data) as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // The data-protection item already exists; keep its bytes and drop the legacy copy.
            guard let existing = loadKey(InstallationIntegrityKeyQuery.dataProtectionCopy()) else {
                fatalError("Keychain load failed for installation integrity key: \(errSecItemNotFound)")
            }
            SecItemDelete(InstallationIntegrityKeyQuery.legacyDelete() as CFDictionary)
            return existing
        }

        guard status == errSecSuccess else {
            // The legacy item is the only copy of the key until this add succeeds.
            fatalError("Keychain store failed for installation integrity key: \(status)")
        }

        SecItemDelete(InstallationIntegrityKeyQuery.legacyDelete() as CFDictionary)
        return key
    }

    private func generateDataProtectionItem() -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }

        SecItemDelete(InstallationIntegrityKeyQuery.dataProtectionDelete() as CFDictionary)

        let status = SecItemAdd(InstallationIntegrityKeyQuery.dataProtectionAdd(data: data) as CFDictionary, nil)
        guard status == errSecSuccess else {
            fatalError("Keychain store failed for installation integrity key: \(status)")
        }

        return key
    }
}
