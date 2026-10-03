import Testing
@testable import Keyameleon

@Test("Assignments explains the initial Input Source delay")
@MainActor
func assignmentNoteExplainsInitialInputSourceDelay() {
    let note = OnboardingAssignmentsStep.switchingNote
    #expect(note.contains("Initial key presses may still use the previous Input Source"))
    #expect(note.contains("guarantee") == false)
}
