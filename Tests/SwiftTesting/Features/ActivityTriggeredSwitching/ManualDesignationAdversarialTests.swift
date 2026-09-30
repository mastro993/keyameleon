import CryptoKit
import Foundation
import Testing
@testable import Keyameleon

@Test("Saved designation cannot override newly shared or unstable identity evidence", arguments: [true, false])
@MainActor
func savedDesignationRequiresCurrentEligibleEvidence(sharedIdentity: Bool) throws {
    var catalog = PhysicalKeyboardCatalog()
    catalog.apply(.connected(designationAdversarialFacts(serviceID: 1, productID: 100)))
    catalog.apply(.connected(designationAdversarialFacts(serviceID: 2, productID: 200)))
    let original = try #require(catalog.physicalKeyboards.first)
    try #require(original.assignmentState == .unsupported(.ambiguousIdentity))
    let records = InMemoryPhysicalKeyboardRecordStore()
    let designations = InMemoryManualPhysicalKeyboardDesignationStore()
    let key = InMemoryInstallationIntegrityKeyProvider()
    let savedDesignation = SavedManualPhysicalKeyboardDesignation(
        identityKey: original.id.rawValue,
        productName: original.productName,
        confirmedName: "Desk",
        authenticationTag: ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
            identityKey: original.id.rawValue,
            productName: original.productName,
            confirmedName: "Desk",
            integrityKey: key.integrityKey()
        )
    )
    designations.save(savedDesignation)
    let assignment = try #require(KeyboardAssignment(inputSourceIdentifier: "com.example.us"))
    records.saveAssignment(identityKey: original.id.rawValue, productName: original.productName, assignment: assignment)
    let resolver = PhysicalKeyboardPresentationResolver(
        recordStore: records, designationStore: designations, integrityKeyProvider: key
    )
    try #require(try resolver.resolve(original).keyboardAssignment == assignment)

    catalog.apply(.connected(designationAdversarialFacts(
        serviceID: 3, productID: 100, serialNumber: sharedIdentity ? "other-serial" : nil
    )))
    let changed = try #require(catalog.physicalKeyboards.first)
    try #require(changed.id == original.id)
    let reason: PhysicalKeyboardUnsupportedReason = sharedIdentity ? .sharedIdentity : .unstableIdentity
    try #require(changed.assignmentState == .unsupported(reason))
    #expect(try resolver.resolve(changed).assignmentState == .unsupported(reason))
    #expect(designations.designation(forIdentityKey: original.id.rawValue) == savedDesignation)
    #expect(records.record(forIdentityKey: original.id.rawValue)?.keyboardAssignment == assignment)

    catalog.apply(.disconnected(serviceID: 3))
    let recovered = try #require(catalog.physicalKeyboards.first)
    #expect(try resolver.resolve(recovered).keyboardAssignment == assignment)
}

@Test("Designation authentication binds each field even when it contains separators", arguments: [true, false])
func designationAuthenticationBindsFieldBoundaries(moveIdentityBoundary: Bool) {
    let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    let identityKey = "identity:board|anchor:serial:s1"
    let productName = "Maker\u{1e}Model"
    let tag = ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
        identityKey: identityKey, productName: productName, confirmedName: "Desk", integrityKey: key
    )
    let original = SavedManualPhysicalKeyboardDesignation(
        identityKey: identityKey, productName: productName, confirmedName: "Desk", authenticationTag: tag
    )
    #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(original, integrityKey: key))
    let tampered = SavedManualPhysicalKeyboardDesignation(
        identityKey: moveIdentityBoundary ? identityKey + "\u{1e}Maker" : identityKey,
        productName: moveIdentityBoundary ? "Model" : "Maker",
        confirmedName: moveIdentityBoundary ? "Desk" : "Model\u{1e}Desk",
        authenticationTag: tag
    )
    #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(tampered, integrityKey: key) == false)
}

@Test("Legacy designation tags remain valid only when their field boundaries are unambiguous")
func legacyDesignationAuthenticationPreservesUnambiguousEvidence() {
    let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    let tag = Data(HMAC<SHA256>.authenticationCode(
        for: Data("identity:board|anchor:serial:s1\u{1e}Maker\u{1e}Desk".utf8), using: key
    ))
    let saved = SavedManualPhysicalKeyboardDesignation(
        identityKey: "identity:board|anchor:serial:s1",
        productName: "Maker",
        confirmedName: "Desk",
        authenticationTag: tag
    )
    #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(saved, integrityKey: key))
    let tampered = SavedManualPhysicalKeyboardDesignation(
        identityKey: saved.identityKey, productName: saved.productName, confirmedName: "Other", authenticationTag: tag
    )
    #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(tampered, integrityKey: key) == false)
}

@Test("Legacy designation tags with ambiguous field boundaries fail closed", arguments: [true, false])
func legacyDesignationAuthenticationRejectsAmbiguousEvidence(moveNameBoundary: Bool) {
    let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    let tag = Data(HMAC<SHA256>.authenticationCode(
        for: Data("identity:board|anchor:serial:s1\u{1e}Maker\u{1e}Model\u{1e}Desk".utf8), using: key
    ))
    let saved = SavedManualPhysicalKeyboardDesignation(
        identityKey: "identity:board|anchor:serial:s1",
        productName: moveNameBoundary ? "Maker" : "Maker\u{1e}Model",
        confirmedName: moveNameBoundary ? "Model\u{1e}Desk" : "Desk",
        authenticationTag: tag
    )
    #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(saved, integrityKey: key) == false)
}

@Test("Malformed designation tags and another installation key cannot authenticate evidence")
func designationAuthenticationRejectsMalformedTagsAndWrongKey() throws {
    let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    let tag = ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
        identityKey: "identity:board", productName: "Board", confirmedName: "Desk", integrityKey: key
    )
    let original = SavedManualPhysicalKeyboardDesignation(
        identityKey: "identity:board", productName: "Board", confirmedName: "Desk", authenticationTag: tag
    )
    try #require(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(original, integrityKey: key))
    let malformedTags = [
        Data(),
        Data(tag.prefix(1)),
        Data(tag.dropLast()),
        tag + Data([0]),
        Data([3]) + Data(tag.dropFirst()),
        Data(repeating: 0, count: 1024)
    ]
    for malformedTag in malformedTags {
        let corrupted = SavedManualPhysicalKeyboardDesignation(
            identityKey: original.identityKey,
            productName: original.productName,
            confirmedName: original.confirmedName,
            authenticationTag: malformedTag
        )
        #expect(ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(corrupted, integrityKey: key) == false)
    }
    let otherInstallationKey = SymmetricKey(data: Data(repeating: 0xCD, count: 32))
    #expect(
        ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(original, integrityKey: otherInstallationKey) == false
    )
}

private func designationAdversarialFacts(
    serviceID: UInt64,
    productID: UInt32,
    serialNumber: String? = "same-serial"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(rawValue: "board", isBuiltIn: false, serialNumber: serialNumber),
        name: "Board", transport: .usb, isBuiltIn: false,
        vendorID: 500, productID: productID, modelNumber: "Model", serialNumber: serialNumber
    )
}
