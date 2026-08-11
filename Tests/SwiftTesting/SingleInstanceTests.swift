import Foundation
import Testing
@testable import Keyameleon

@Test("Single-instance ownership rejects a second holder")
func singleInstanceOwnershipRejectsSecondHolder() throws {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyameleonSingleInstanceTests-\(UUID().uuidString).lock")
    defer { try? FileManager.default.removeItem(at: path) }

    do {
        let first = try #require(KeyameleonSingleInstanceLock.acquire(at: path))
        #expect(KeyameleonSingleInstanceLock.acquire(at: path) == nil)
        _ = first
    }

    #expect(KeyameleonSingleInstanceLock.acquire(at: path) != nil)
}

@Test("Single-instance ownership rejects unsafe lock paths")
func singleInstanceOwnershipRejectsUnsafeLockPaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyameleonSingleInstanceTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(KeyameleonSingleInstanceLock.acquire(at: directory) == nil)
}
