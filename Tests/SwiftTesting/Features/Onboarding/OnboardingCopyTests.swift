import Testing
@testable import Keyameleon

@Test("Guided setup assignment step explains the Activation Activity limit")
@MainActor
func guidedSetupAssignmentStepExplainsActivationActivityLimit() {
    let copy = KeyameleonOnboardingView.assignmentStepSubtitle
    #expect(copy == """
    Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings.

    When you start typing on a different Physical Keyboard, that first key press can still use the previous Input Source. Keyameleon then selects that keyboard's Keyboard Assignment.
    """)
    #expect(copy.contains("First-Key") == false)
    #expect(copy.contains("first-key") == false)
    #expect(copy.contains("guarantee") == false)
    #expect(copy.contains("best-effort") == false)
}
