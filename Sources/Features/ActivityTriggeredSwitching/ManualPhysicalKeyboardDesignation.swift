import CryptoKit
import Foundation

/// Saved user decision that one stable external identity group is a Physical Keyboard.
struct SavedManualPhysicalKeyboardDesignation: Equatable, Sendable {
    let identityKey: String
    let productName: String
    let confirmedName: String
    let authenticationTag: Data

    init(
        identityKey: String,
        productName: String,
        confirmedName: String,
        authenticationTag: Data
    ) {
        self.identityKey = identityKey
        self.productName = productName
        self.confirmedName = confirmedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.authenticationTag = authenticationTag
    }
}

/// CryptoKit authentication for designation evidence. Integrity key lives in Keychain.
enum ManualPhysicalKeyboardDesignationAuthenticator {
    static func authenticationTag(
        identityKey: String,
        productName: String,
        confirmedName: String,
        integrityKey: SymmetricKey
    ) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(
            for: payloadData(
                identityKey: identityKey,
                productName: productName,
                confirmedName: confirmedName
            ),
            using: integrityKey
        )
        return Data(mac)
    }

    static func isAuthentic(
        _ designation: SavedManualPhysicalKeyboardDesignation,
        integrityKey: SymmetricKey
    ) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(
            designation.authenticationTag,
            authenticating: payloadData(
                identityKey: designation.identityKey,
                productName: designation.productName,
                confirmedName: designation.confirmedName
            ),
            using: integrityKey
        )
    }

    /// Payload holds only designation fields. Never includes Key Content.
    static func payloadData(
        identityKey: String,
        productName: String,
        confirmedName: String
    ) -> Data {
        let normalizedName = confirmedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = "\(identityKey)\u{1e}\(productName)\u{1e}\(normalizedName)"
        return Data(payload.utf8)
    }
}
