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

/// Guided-setup session for Manual Physical Keyboard Designation.
enum ManualPhysicalKeyboardDesignationPhase: Equatable, Sendable {
    case idle
    case awaitingRemoval(PhysicalKeyboardRecordID)
    case awaitingReturn(PhysicalKeyboardRecordID)
    case awaitingNameConfirmation(PhysicalKeyboardRecordID, productName: String)
}

/// Approved evidence rules for offering and completing Manual Physical Keyboard Designation.
enum ManualPhysicalKeyboardDesignationEvidenceRules {
    /// Offer only for external, identity-based, ambiguous groups.
    /// Missing, unstable, and shared identity stay unsupported with no offer.
    static func offersDesignation(for physicalKeyboard: PhysicalKeyboard) -> Bool {
        guard !physicalKeyboard.isBuiltIn else {
            return false
        }

        guard physicalKeyboard.id.isIdentityBased else {
            return false
        }

        guard case .unsupported(.ambiguousIdentity) = physicalKeyboard.assignmentState else {
            return false
        }

        return true
    }

    /// Return step accepts the same identity group when evidence stays stable and not shared.
    /// Ambiguous multi-interface facts remain valid — that is the approved exceptional case.
    static func acceptsReturn(
        connected: [PhysicalKeyboard],
        expectedID: PhysicalKeyboardRecordID
    ) -> PhysicalKeyboard? {
        guard expectedID.isIdentityBased else {
            return nil
        }

        guard let returned = connected.first(where: { $0.id == expectedID }) else {
            return nil
        }

        guard !returned.isBuiltIn else {
            return nil
        }

        switch returned.assignmentState {
        case .unsupported(.missingIdentity),
            .unsupported(.unstableIdentity),
            .unsupported(.sharedIdentity):
            return nil
        case .unsupported(.ambiguousIdentity), .unassigned, .assigned:
            return returned
        }
    }

    /// Incomplete or empty confirmed name is invalid evidence.
    static func acceptsConfirmedName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
