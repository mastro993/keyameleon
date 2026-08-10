import Carbon.HIToolbox
import Foundation

@MainActor
protocol InputSourceProviding: AnyObject {
    func eligibleInputSources() -> [EligibleInputSource]
}

@MainActor
final class SystemInputSourceProvider: InputSourceProviding {
    func eligibleInputSources() -> [EligibleInputSource] {
        guard let unmanagedList = TISCreateInputSourceList(nil, false) else {
            return []
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

        return EligibleInputSourceCatalog.eligible(from: facts)
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
