import Foundation
import Testing
@testable import Keyameleon

@Test("Removing the legacy Diagnostic Data store leaves other files alone")
func removingLegacyDiagnosticStoreLeavesOtherFilesAlone() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "KeyameleonLegacyDiagnosticDataTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for fileName in KeyameleonLegacyDiagnosticData.storeFileNames {
        try Data("store".utf8).write(to: directory.appending(path: fileName))
    }
    try Data("kept".utf8).write(to: directory.appending(path: "PhysicalKeyboards.store"))

    KeyameleonLegacyDiagnosticData.removeStoreFiles(in: directory)
    KeyameleonLegacyDiagnosticData.removeStoreFiles(in: directory)

    #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
            == ["PhysicalKeyboards.store"]
    )
}
