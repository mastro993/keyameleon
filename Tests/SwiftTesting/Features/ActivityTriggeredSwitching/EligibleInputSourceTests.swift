import Foundation
import Testing
@testable import Keyameleon

@Test("Eligible input sources contain enabled selectable keyboard layouts only")
func eligibleInputSourcesContainEnabledSelectableKeyboardLayoutsOnly() {
    let inputSources = EligibleInputSourceCatalog.eligible(
        from: [
            InputSourceFacts(
                identifier: "com.example.us",
                name: "U.S.",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.disabled",
                name: "Disabled",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: false,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.parent-input-method",
                name: "Stateful Input Method",
                category: .keyboard,
                type: .keyboardInputMethodWithModes,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.palette",
                name: "Palette",
                category: .palette,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            ),
            InputSourceFacts(
                identifier: "com.example.custom",
                name: "Custom Layout",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true
            )
        ]
    )

    #expect(inputSources.map(\.name) == ["Custom Layout", "U.S."])
    #expect(inputSources.allSatisfy { !$0.name.contains("com.example") })
}

@Test("Eligible input source locale code names the layout locale, not its language")
func eligibleInputSourceLocaleCodeNamesLayoutLocale() {
    let inputSources = EligibleInputSourceCatalog.eligible(
        from: [
            InputSourceFacts(
                identifier: "com.apple.keylayout.US",
                name: "U.S.",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: ["en", "it"]
            ),
            InputSourceFacts(
                identifier: "com.apple.keylayout.Italian-Pro",
                name: "Italian",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: ["it"]
            ),
            InputSourceFacts(
                identifier: "com.apple.keylayout.ABC",
                name: "ABC",
                category: .keyboard,
                type: .keyboardLayout,
                isEnabled: true,
                isSelectCapable: true,
                languages: []
            )
        ]
    )

    #expect(inputSources.map(\.localeCode) == [nil, "IT", "US"])
}
