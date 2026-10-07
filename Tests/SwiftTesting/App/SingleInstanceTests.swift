import Foundation
import Testing
@testable import Keyameleon

@Test("Every build locks the shipped device")
func defaultLockIsShippedDevice() {
    #expect(SingleInstanceLock.defaultLockURL.path == "/dev/null")
}

@Test("Single-instance ownership rejects a second holder")
func singleInstanceOwnershipRejectsSecondHolder() throws {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyameleonSingleInstanceTests-\(UUID().uuidString).lock")
    defer { try? FileManager.default.removeItem(at: path) }

    do {
        let first = try #require(SingleInstanceLock.acquire(at: path))
        #expect(SingleInstanceLock.acquire(at: path) == nil)
        _ = first
    }

    #expect(SingleInstanceLock.acquire(at: path) != nil)
}

@Test("Single-instance ownership rejects unsafe lock paths")
func singleInstanceOwnershipRejectsUnsafeLockPaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeyameleonSingleInstanceTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(SingleInstanceLock.acquire(at: directory) == nil)
}
