import CoreHID
import Testing
@testable import Keyameleon

@Test("Keyboard usage stays recognized without LED evidence")
func keyboardUsageWithoutLEDIsPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: true,
        hasKeyInputElement: false
    )

    #expect(recognition.isPhysicalKeyboard)
}

@Test("Keyboard input elements identify a Physical Keyboard without advertised keyboard usage")
func keyboardInputElementIdentifiesPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: false,
        hasKeyInputElement: true
    )

    #expect(recognition.isPhysicalKeyboard)
}

@Test("Pointer without keyboard usage or key input stays excluded")
func pointerWithoutKeyboardEvidenceIsNotPhysicalKeyboard() {
    let recognition = PhysicalKeyboardHIDRecognition(
        hasKeyInputUsage: false,
        hasKeyInputElement: false
    )

    #expect(!recognition.isPhysicalKeyboard)
}

@Test(
    "Keyboard, keypad, and consumer usages identify a Physical Keyboard",
    arguments: [
        HIDUsage.genericDesktop(.keyboard),
        .genericDesktop(.keypad),
        .keyboardOrKeypad(nil),
        .consumer(.consumerControl)
    ]
)
func keyInputUsageIdentifiesPhysicalKeyboard(usage: HIDUsage) {
    #expect(PhysicalKeyboardHIDInspection.isKeyInputUsage(usage))
}

@Test(
    "Usages without key input do not identify a Physical Keyboard",
    arguments: [HIDUsage.genericDesktop(.mouse), .genericDesktop(.pointer)]
)
func usageWithoutKeyInputDoesNotIdentifyPhysicalKeyboard(usage: HIDUsage) {
    #expect(!PhysicalKeyboardHIDInspection.isKeyInputUsage(usage))
}
