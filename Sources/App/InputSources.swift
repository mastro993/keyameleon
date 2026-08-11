import Carbon.HIToolbox
import Foundation

@MainActor
protocol InputSourceProviding: AnyObject {
    func eligibleInputSources() -> [EligibleInputSource]
}

@MainActor
protocol InputSourceSelecting: AnyObject {
    /// Exact Input Source identifier currently selected for keyboard input.
    func currentInputSourceIdentifier() -> String?

    /// Request selection of the exact Input Source. Does not guarantee First-Key timing.
    /// Returns `true` only when the post-select readback matches the requested identifier.
    func selectAndVerifyInputSource(identifier: String) -> Bool
}

@MainActor
protocol InputSourceChangeObserving: AnyObject {
    /// Observe external Input Source selection changes (manual, shortcut, other apps).
    func start(onChange: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class NoOpInputSourceChangeObserver: InputSourceChangeObserving {
    func start(onChange: @escaping @MainActor () -> Void) {}
    func stop() {}
}

@MainActor
final class SystemInputSourceChangeObserver: InputSourceChangeObserving {
    // Token removed from DistributedNotificationCenter on stop; unsafe for deinit only.
    private nonisolated(unsafe) var observer: NSObjectProtocol?

    func start(onChange: @escaping @MainActor () -> Void) {
        stop()
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        observer = DistributedNotificationCenter.default().addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onChange()
            }
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}

/// Typed fact when the observed current Input Source differs from the Active assignment.
struct InputSourceMismatch: Equatable, Sendable {
    let currentInputSourceIdentifier: String
    let assignedInputSourceIdentifier: String
}

@MainActor
final class SystemInputSourceProvider: InputSourceProviding, InputSourceSelecting {
    func eligibleInputSources() -> [EligibleInputSource] {
        inputSourceFacts().map { facts in
            EligibleInputSourceCatalog.eligible(from: facts)
        } ?? []
    }

    func currentInputSourceIdentifier() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return stringProperty(source, kTISPropertyInputSourceID)
    }

    func selectAndVerifyInputSource(identifier: String) -> Bool {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return false
        }

        if currentInputSourceIdentifier() == normalized {
            return true
        }

        // Capture prior Input Source so a failed exact readback can restore it.
        let previousIdentifier = currentInputSourceIdentifier()

        guard let source = inputSource(withIdentifier: normalized) else {
            return false
        }

        let status = TISSelectInputSource(source)
        guard status == noErr else {
            return false
        }

        if currentInputSourceIdentifier() == normalized {
            return true
        }

        // Exact verification failed: restore prior Input Source when possible.
        if let previousIdentifier,
           let previousSource = inputSource(withIdentifier: previousIdentifier)
        {
            _ = TISSelectInputSource(previousSource)
        }

        return false
    }

    private func inputSourceFacts() -> [InputSourceFacts]? {
        guard let unmanagedList = TISCreateInputSourceList(nil, false) else {
            return nil
        }

        let list = unmanagedList.takeRetainedValue()
        var facts: [InputSourceFacts] = []

        for index in 0..<CFArrayGetCount(list) {
            let source = unsafeBitCast(
                CFArrayGetValueAtIndex(list, index),
                to: TISInputSource.self
            )

            guard
                let identifier = stringProperty(source, kTISPropertyInputSourceID),
                let name = stringProperty(source, kTISPropertyLocalizedName)
            else {
                continue
            }

            facts.append(
                InputSourceFacts(
                    identifier: identifier,
                    name: name,
                    category: category(for: stringProperty(source, kTISPropertyInputSourceCategory)),
                    type: type(for: stringProperty(source, kTISPropertyInputSourceType)),
                    isEnabled: boolProperty(source, kTISPropertyInputSourceIsEnabled),
                    isSelectCapable: boolProperty(source, kTISPropertyInputSourceIsSelectCapable)
                )
            )
        }

        return facts
    }

    private func inputSource(withIdentifier identifier: String) -> TISInputSource? {
        let properties = [kTISPropertyInputSourceID as String: identifier] as CFDictionary
        guard let unmanagedList = TISCreateInputSourceList(properties, true) else {
            return nil
        }

        let list = unmanagedList.takeRetainedValue()
        guard CFArrayGetCount(list) > 0 else {
            return nil
        }

        return unsafeBitCast(CFArrayGetValueAtIndex(list, 0), to: TISInputSource.self)
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return false
        }

        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }

    private func category(for value: String?) -> InputSourceCategory {
        guard let value else {
            return .other
        }

        if value == (kTISCategoryKeyboardInputSource as String) {
            return .keyboard
        }

        if value == (kTISCategoryPaletteInputSource as String) {
            return .palette
        }

        if value == (kTISCategoryInkInputSource as String) {
            return .ink
        }

        return .other
    }

    private func type(for value: String?) -> InputSourceType {
        guard let value else {
            return .other
        }

        if value == (kTISTypeKeyboardLayout as String) {
            return .keyboardLayout
        }

        if value == (kTISTypeKeyboardInputMethodWithoutModes as String) {
            return .keyboardInputMethodWithoutModes
        }

        if value == (kTISTypeKeyboardInputMethodModeEnabled as String) {
            return .keyboardInputMethodWithModes
        }

        if value == (kTISTypeKeyboardInputMode as String) {
            return .keyboardInputMode
        }

        return .other
    }
}
