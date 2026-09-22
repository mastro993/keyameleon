import Foundation
import Testing
@testable import Keyameleon

@Test("Panel VoiceOver announces Switching Status, assignments, and actions once")
@MainActor
func menuBarPanelVoiceOverAnnouncesIntegratedSurface() {
    let content = makeAccessiblePanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: "Travel", identifier: "travel", isActive: true)
        ],
        assignedInputSourceNames: panelAccessibilityNames("travel", "Italian")
    )
    let accessibility = content.accessibility

    #expect(accessibility.panel.label == "Keyameleon")
    #expect(accessibility.panel.value == "Ready")
    #expect(accessibility.about.label == "About Keyameleon")
    #expect(accessibility.actions.map(\.label) == [
        "Pause",
        "Settings",
        "Quit Keyameleon"
    ])
    #expect(accessibility.voiceOverOrderLabels == [
        "Keyameleon",
        "About Keyameleon",
        "Travel",
        "Pause",
        "Settings",
        "Quit Keyameleon"
    ])
}

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
        assignedInputSourceNames: panelAccessibilityNames(
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

@Test("Empty Keyboards state has one combined VoiceOver announcement")
func menuBarAssignmentEmptyStateVoiceOverIsCombined() {
    let content = makeAccessiblePanelContent(outcome: .readyFixture())
    let empty = content.accessibility.items.first

    #expect(content.accessibility.items.count == 1)
    #expect(empty?.label == "No assigned keyboards")
    #expect(empty?.value == "Open Keyameleon Settings to assign keyboards.")
}

@Test("Keyboard focus follows header, assignments, then tray actions")
@MainActor
func menuBarPanelKeyboardFocusOrderVisitsAssignmentsThenActions() {
    let assigned = makeAccessiblePanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: "Travel", identifier: "travel", isActive: true),
            makeAssignedAccessibleKeyboard(name: "Desk", identifier: "desk")
        ],
        assignedInputSourceNames: panelAccessibilityNames("travel", "Italian", "desk", "US")
    )
    let empty = makeAccessiblePanelContent(outcome: .readyFixture())

    #expect(assigned.accessibility.keyboardFocusOrder == [
        .about,
        .assignment(id: "desk"),
        .assignment(id: "travel"),
        .action(id: .pause),
        .action(id: .settings),
        .action(id: .quit)
    ])
    #expect(empty.accessibility.keyboardFocusOrder == [
        .about,
        .action(id: .pause),
        .action(id: .settings),
        .action(id: .quit)
    ])
    #expect(assigned.accessibility.keyboardOperationTitles == [
        "About Keyameleon",
        "Desk",
        "Travel",
        "Pause",
        "Settings",
        "Quit Keyameleon"
    ])
}

@Test("Paused and Ready live updates change Switching Status speech and tray actions")
@MainActor
func menuBarPanelAccessibilityLiveUpdatesWithSwitchingStatus() {
    let ready = makeAccessiblePanelContent(outcome: .readyFixture())
    let paused = makeAccessiblePanelContent(outcome: .pausedFixture())
    let permission = makeAccessiblePanelContent(outcome: .permissionRequiredFixture())

    #expect(ready.accessibility.panel.value == "Ready")
    #expect(paused.accessibility.panel.value == "Paused")
    #expect(permission.accessibility.panel.value == "Permission Required")
    #expect(ready.accessibility.actions.first?.label == "Pause")
    #expect(paused.accessibility.actions.first?.label == "Resume")
    #expect(permission.accessibility.actions.map(\.label) == [
        "Pause",
        "Settings",
        "Quit Keyameleon"
    ])
}

@Test("Live assignment changes appear in VoiceOver and keyboard order")
@MainActor
func menuBarPanelAccessibilityLiveUpdatesWithAssignments() {
    let empty = makeAccessiblePanelContent(outcome: .readyFixture())
    let assigned = makeAccessiblePanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: "Travel", identifier: "travel", isActive: true)
        ],
        assignedInputSourceNames: panelAccessibilityNames("travel", "Italian")
    )

    #expect(empty.accessibility.items.first?.label == "No assigned keyboards")
    #expect(assigned.accessibility.items.map(\.label) == ["Travel"])
    #expect(assigned.accessibility.items.map(\.value) == ["Italian, Active"])
    #expect(assigned.accessibility.keyboardFocusOrder.prefix(2) == [
        .about,
        .assignment(id: "travel")
    ])
}

@Test("Reduce Transparency uses opaque chrome; default keeps Liquid Glass")
func menuBarPanelChromeFollowsReduceTransparency() {
    #expect(
        MenuBarPanelChrome.resolve(reduceTransparency: false, increasedContrast: false)
            == MenuBarPanelChrome(surface: .liquidGlass, assignmentEmphasis: .standard)
    )
    #expect(
        MenuBarPanelChrome.resolve(reduceTransparency: true, increasedContrast: false)
            == MenuBarPanelChrome(surface: .opaque, assignmentEmphasis: .standard)
    )
}

@Test("Increased contrast adds a stronger assignment-card stroke")
func menuBarPanelChromeFollowsIncreasedContrast() {
    #expect(
        MenuBarPanelChrome.resolve(reduceTransparency: false, increasedContrast: true)
            .assignmentEmphasis == .highContrast
    )
    #expect(
        MenuBarPanelChrome.resolve(reduceTransparency: true, increasedContrast: true)
            == MenuBarPanelChrome(surface: .opaque, assignmentEmphasis: .highContrast)
    )
}

@Test("Long Physical Keyboard Names stay complete in speech at the 280 pt panel width")
func menuBarPanelLongNamesStayCompleteInSpeech() {
    let name = "Keychron K2 HE ISO Nordic Traveler Custom Mechanical"
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedAccessibleKeyboard(name: name, identifier: "long")
        ],
        assignedInputSourceNames: panelAccessibilityNames("long", "Italian - QWERTY")
    )
    let row = list.rows[0]

    #expect(row.accessibilityLabel == name)
    #expect(row.accessibilityValue == "Italian - QWERTY, Connected")
}

private func makeAccessiblePanelContent(
    outcome: ActivityTriggeredSwitchingOutcome,
    physicalKeyboards: [PhysicalKeyboard] = [],
    assignedInputSourceNames: [PhysicalKeyboardRecordID: String] = [:],
    marketingVersion: String? = "0.1.0"
) -> MenuBarPanelContent {
    MenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: physicalKeyboards,
        assignedInputSourceNames: assignedInputSourceNames,
        marketingVersion: marketingVersion
    )
}

private extension ActivityTriggeredSwitchingOutcome {
    static func readyFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(switchingStatus: .ready, availableActions: [.pause, .openSystemSettings, .checkAgain])
    }

    static func pausedFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(switchingStatus: .paused, availableActions: [.resume])
    }

    static func permissionRequiredFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .permissionRequired,
            availableActions: [.pause, .requestPermission, .openSystemSettings, .checkAgain]
        )
    }

    static func fixture(
        switchingStatus: SwitchingStatus,
        availableActions: Set<ActivityTriggeredSwitchingAction>
    ) -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: switchingStatus,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: availableActions
        )
    }
}

private func panelAccessibilityNames(_ pairs: String...) -> [PhysicalKeyboardRecordID: String] {
    Dictionary(
        uniqueKeysWithValues: stride(from: 0, to: pairs.count, by: 2).map { index in
            (PhysicalKeyboardRecordID(rawValue: pairs[index]), pairs[index + 1])
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
