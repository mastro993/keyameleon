import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: verify-sparkle-ed-keys.swift <private-key-file> <public-key-file>")
}

do {
    let privateText = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let publicText = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
    guard let privateKey = Data(base64Encoded: privateText),
          let publicKey = Data(base64Encoded: publicText), publicKey.count == 32 else {
        fail("Sparkle EdDSA key files are invalid")
    }

    let expectedPublicKey: Data
    switch privateKey.count {
    case 32:
        expectedPublicKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            .publicKey.rawRepresentation
    case 96:
        // Sparkle's legacy export contains its expanded private key followed by its public key.
        expectedPublicKey = privateKey.suffix(32)
    default:
        fail("Sparkle EdDSA private key must contain a 32-byte seed or 96-byte legacy export")
    }
    guard publicKey == expectedPublicKey else {
        fail("Sparkle EdDSA public key does not match the private key")
    }
} catch {
    fail("Could not read or validate Sparkle EdDSA key files")
}
