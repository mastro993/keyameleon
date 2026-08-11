import Darwin
import Foundation

/// Holds a machine-wide advisory lock for the lifetime of the Keyameleon process.
final class KeyameleonSingleInstanceLock {
    static let defaultLockURL = URL(
        fileURLWithPath: "/dev/null"
    )
    static let blockedLaunchExitCode: Int32 = 75

    private let fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    /// Acquires the machine-wide lock from a stable kernel device inode.
    ///
    /// `/dev/null` is available to every local user and cannot be replaced by
    /// deleting an app-owned lock file while the process is running.
    static func acquire() -> KeyameleonSingleInstanceLock? {
        let fileDescriptor = open(defaultLockURL.path, O_RDWR | O_CLOEXEC)
        guard fileDescriptor >= 0 else {
            return nil
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            _ = close(fileDescriptor)
            return nil
        }

        return KeyameleonSingleInstanceLock(fileDescriptor: fileDescriptor)
    }

    /// Acquires a file lock at an injected path for deterministic unit tests.
    static func acquire(at url: URL) -> KeyameleonSingleInstanceLock? {
        // The lock file must be writable by every local user because ownership is
        // intentionally shared by the test processes. Restore the process umask
        // immediately after creation so later users can open the same file.
        let previousUmask = umask(0)
        defer { _ = umask(previousUmask) }

        let flags = O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW | O_EXLOCK | O_NONBLOCK
        let fileDescriptor = url.path.withCString { path in
            open(path, flags, mode_t(0o666))
        }

        guard fileDescriptor >= 0 else {
            return nil
        }

        return KeyameleonSingleInstanceLock(fileDescriptor: fileDescriptor)
    }

    deinit {
        _ = close(fileDescriptor)
    }
}
