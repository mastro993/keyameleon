import Foundation
import Testing
@testable import Keyameleon

@Test("Assignment row VoiceOver uses Physical Keyboard Name, Input Source, condition, and warning once")
func menuBarAssignmentRowVoiceOverAvoidsDuplicateSpeech() throws {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: "Travel", identifier: "travel", isActive: true),
            makeAssignedAccessibleKeyboard(name: "Desk", identifier: "desk"),
            makeAssignedAccessibleKeyboard(
                name: "Studio",
                identifier: "studio",
                connectionState: .disconnected
            ),
            makeAssignedAccessibleKeyboard(name: "Broken", identifier: "broken")
        ],
        assignedInputSources: panelAccessibilityNames(
            "travel", "Italian",
            "desk", "US",
            "studio", "French"
        )
    )
    let travel = try #require(list.rows.first { $0.id == "travel" })
    let desk = try #require(list.rows.first { $0.id == "desk" })
    let studio = try #require(list.rows.first { $0.id == "studio" })
    let broken = try #require(list.rows.first { $0.id == "broken" })

    #expect(travel.accessibilityLabel == "Travel")
    #expect(travel.accessibilityValue == "Italian, Active")
    #expect(travel.accessibilityValue.contains("Travel") == false)
    #expect(desk.accessibilityValue == "US, Connected")
    #expect(studio.accessibilityValue == "French, Disconnected")
    #expect(broken.accessibilityLabel == "Broken")
    #expect(broken.accessibilityValue == "Unavailable Input Source, Connected, Unavailable Keyboard Assignment")
}

@Test("Empty keyboard list retains its native accessibility copy")
func menuBarAssignmentEmptyStateVoiceOverIsCombined() {
    let list = MenuBarAssignmentList(physicalKeyboards: [], assignedInputSources: [:])
    #expect(list.emptyTitle == "No assigned keyboards")
    #expect(list.emptyDescription == "Open Keyameleon Settings to assign keyboards.")
}

@Test("Long Physical Keyboard Names stay complete in speech at the 320 pt panel width")
func menuBarPanelLongNamesStayCompleteInSpeech() {
    let name = "Keychron K2 HE ISO Nordic Traveler Custom Mechanical"
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: name, identifier: "long")
        ],
        assignedInputSources: panelAccessibilityNames("long", "Italian - QWERTY")
    )
    let row = list.rows[0]

    #expect(row.accessibilityLabel == name)
    #expect(row.accessibilityValue == "Italian - QWERTY, Connected")
}

private func panelAccessibilityNames(_ pairs: String...) -> [PhysicalKeyboardRecordID: EligibleInputSource] {
    Dictionary(
        uniqueKeysWithValues: stride(from: 0, to: pairs.count, by: 2).map { index in
            (
                PhysicalKeyboardRecordID(rawValue: pairs[index]),
                EligibleInputSource(
                    identifier: "com.example.\(pairs[index])",
                    name: pairs[index + 1]
                )
            )
        }
    )
}

private func makeAssignedAccessibleKeyboard(
    name: String,
    identifier: String,
    connectionState: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false
) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: identifier),
        productName: name,
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "com.example.us")!),
        connectedServiceCount: connectionState == .connected ? 1 : 0,
        connectionState: connectionState,
        isActive: isActive
    )
}
