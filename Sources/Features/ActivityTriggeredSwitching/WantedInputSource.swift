import Foundation

/// The Input Source Keyameleon aims for, and the assignment it comes from.
///
/// Kept for Retry Now and to follow edits of that assignment.
struct WantedInputSource: Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        case keyboard(PhysicalKeyboardRecordID)
        case app(bundleIdentifier: String, name: String)
    }

    let origin: Origin
    let inputSourceIdentifier: String

    var physicalKeyboardID: PhysicalKeyboardRecordID? {
        guard case let .keyboard(physicalKeyboardID) = origin else { return nil }
        return physicalKeyboardID
    }

    var appBundleIdentifier: String? {
        guard case let .app(bundleIdentifier, _) = origin else { return nil }
        return bundleIdentifier
    }

    /// The Frontmost App's App Assignment wins; otherwise the Active Physical
    /// Keyboard's Keyboard Assignment; otherwise there is none.
    static func resolve(
        appAssignment: AppAssignment?,
        activePhysicalKeyboard: PhysicalKeyboard?
    ) -> WantedInputSource? {
        if let appAssignment {
            return WantedInputSource(
                origin: .app(bundleIdentifier: appAssignment.bundleIdentifier, name: appAssignment.appName),
                inputSourceIdentifier: appAssignment.inputSourceIdentifier
            )
        }
        guard let activePhysicalKeyboard, let assignment = activePhysicalKeyboard.keyboardAssignment else {
            return nil
        }
        return WantedInputSource(
            origin: .keyboard(activePhysicalKeyboard.id),
            inputSourceIdentifier: assignment.inputSourceIdentifier
        )
    }
}
