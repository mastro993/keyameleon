import Foundation
import Testing
@testable import Keyameleon

@Test("Assignments explains the initial Input Source delay")
@MainActor
func assignmentNoteExplainsInitialInputSourceDelay() {
    let note = String(localized: .assignmentsSwitchingNote)
    #expect(note.contains("the first keys may use the previous input source"))
    #expect(note.contains("guarantee") == false)
}
