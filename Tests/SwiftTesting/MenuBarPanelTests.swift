import Foundation
import Testing
@testable import Keyameleon

@Test("Menu-bar panel lists only assigned Physical Keyboards under Keyboard Assignments")
func menuBarPanelListsOnlyAssignedPhysicalKeyboards() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            assignedKeyboard(name: "Desk", id: "desk"),
            unassignedKeyboard(name: "Travel", id: "travel"),
            assignedKeyboard(name: "Studio", id: "studio", inputSource: "com.example.it"),
        ],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "desk"): .available(name: "U.S."),
            PhysicalKeyboardRecordID(rawValue: "studio"): .available(name: "Italian"),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(content.assignmentHeading == "Keyboard Assignments")
    #expect(content.assignmentRows.map(\.physicalKeyboardName) == ["Desk", "Studio"])
    #expect(content.assignmentRows.map(\.assignedInputSourceName) == ["U.S.", "Italian"])
    #expect(content.emptyAssignmentsMessage == nil)
    #expect(content.assignmentsScroll == false)
}

@Test("Menu-bar panel orders Active, connected, then disconnected Physical Keyboards")
func menuBarPanelOrdersActiveConnectedThenDisconnected() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            assignedKeyboard(name: "Zebra", id: "zebra", connection: .disconnected),
            assignedKeyboard(name: "Maple", id: "maple"),
            assignedKeyboard(name: "Active Board", id: "active", isActive: true),
            assignedKeyboard(name: "Cedar", id: "cedar"),
        ],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "zebra"): .available(name: "U.S."),
            PhysicalKeyboardRecordID(rawValue: "maple"): .available(name: "U.S."),
            PhysicalKeyboardRecordID(rawValue: "active"): .available(name: "Italian"),
            PhysicalKeyboardRecordID(rawValue: "cedar"): .available(name: "U.S."),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(
        content.assignmentRows.map(\.physicalKeyboardName)
            == ["Active Board", "Cedar", "Maple", "Zebra"]
    )
    #expect(content.assignmentRows.map(\.conditionMark) == [
        .active,
        .connected,
        .connected,
        .disconnected,
    ])
    #expect(content.assignmentRows.map(\.isDimmed) == [false, false, false, true])
}

@Test("Menu-bar panel marks Unavailable Keyboard Assignment without dropping the saved relation")
func menuBarPanelMarksUnavailableKeyboardAssignment() {
    let named = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            assignedKeyboard(name: "Desk", id: "desk", inputSource: "com.example.gone"),
        ],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "desk"): .unavailable(savedName: "Dvorak"),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )
    let unnamed = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            assignedKeyboard(name: "Desk", id: "desk", inputSource: "com.example.gone"),
        ],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "desk"): .unavailable(savedName: nil),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(named.assignmentRows[0].assignedInputSourceName == "Dvorak")
    #expect(named.assignmentRows[0].warningNote == "Unavailable Keyboard Assignment")
    #expect(unnamed.assignmentRows[0].assignedInputSourceName == "Unavailable Input Source")
    #expect(unnamed.assignmentRows[0].warningNote == "Unavailable Keyboard Assignment")
}

@Test("Menu-bar panel shows a compact empty Keyboard Assignments message")
func menuBarPanelShowsCompactEmptyKeyboardAssignmentsMessage() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [unassignedKeyboard(name: "Travel", id: "travel")],
        assignedInputSources: [:],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(content.assignmentRows.isEmpty)
    #expect(content.emptyAssignmentsMessage == "No Keyboard Assignments")
    #expect(content.quickActions.map(\.id) == [.openKeyameleon, .pause])
}

@Test("Menu-bar panel scrolls Keyboard Assignments after five rows")
func menuBarPanelScrollsKeyboardAssignmentsAfterFiveRows() {
    let five = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: (1...5).map { index in
            assignedKeyboard(name: "Board \(index)", id: "board-\(index)")
        },
        assignedInputSources: Dictionary(
            uniqueKeysWithValues: (1...5).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), MenuBarPanelAssignedInputSource.available(name: "U.S."))
            }
        ),
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )
    let six = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: (1...6).map { index in
            assignedKeyboard(name: "Board \(index)", id: "board-\(index)")
        },
        assignedInputSources: Dictionary(
            uniqueKeysWithValues: (1...6).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), MenuBarPanelAssignedInputSource.available(name: "U.S."))
            }
        ),
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(five.assignmentRows.count == 5)
    #expect(five.assignmentsScroll == false)
    #expect(six.assignmentRows.count == 6)
    #expect(six.assignmentsScroll == true)
}

@Test("Menu-bar panel shows recovery banner only for Permission Required and Temporarily Unavailable")
func menuBarPanelShowsRecoveryBannerOnlyWhenGloballyBlocked() {
    let ready = MenuBarPanelContent.fixture(outcome: .readyFixture())
    let paused = MenuBarPanelContent.fixture(outcome: .pausedFixture())
    let permission = MenuBarPanelContent.fixture(outcome: .permissionRequiredFixture())
    let unavailable = MenuBarPanelContent.fixture(
        outcome: .temporarilyUnavailableFixture(reason: .secureInput)
    )

    #expect(ready.recoveryBanner == nil)
    #expect(paused.recoveryBanner == nil)
    #expect(paused.quickActions.map(\.id) == [.openKeyameleon, .resume])
    #expect(permission.recoveryBanner?.switchingStatusName == "Permission Required")
    #expect(permission.recoveryBanner?.action?.id == .openSystemSettings)
    #expect(unavailable.recoveryBanner?.switchingStatusName == "Temporarily Unavailable")
    #expect(unavailable.recoveryBanner?.detail == "Secure Input is active")
    #expect(unavailable.recoveryBanner?.action == nil)
}

@Test("Menu-bar panel footer uses marketing version and conditional overflow")
func menuBarPanelFooterUsesMarketingVersionAndConditionalOverflow() {
    let content = MenuBarPanelContent.fixture(
        canCheckForUpdates: false,
        hasPendingUncleanExitNotice: true,
        marketingVersion: "1.2.3"
    )
    let fallback = MenuBarPanelContent.fixture(marketingVersion: "  ")

    #expect(content.versionText == "Version 1.2.3")
    #expect(content.overflowActions.map(\.id) == [
        .settings,
        .checkForUpdates,
        .reviewDiagnostics,
        .quit,
    ])
    #expect(content.overflowActions.first { $0.id == .checkForUpdates }?.isEnabled == false)
    #expect(content.overflowActions.map(\.closesPanel) == [true, true, true, true])
    #expect(fallback.versionText == "Version 0.1.0")
}

@Test("Menu-bar panel keyboard focus visits recovery, Quick Actions, then overflow")
func menuBarPanelKeyboardFocusVisitsRecoveryQuickActionsThenOverflow() {
    let ready = MenuBarPanelContent.fixture(outcome: .readyFixture())
    let permission = MenuBarPanelContent.fixture(outcome: .permissionRequiredFixture())

    #expect(ready.keyboardFocusOrder == [.openKeyameleon, .pause, .overflow])
    #expect(
        permission.keyboardFocusOrder
            == [.openSystemSettings, .openKeyameleon, .pause, .overflow]
    )
    #expect(ready.focusSequence == ["openKeyameleon", "pause", "overflow"])
    #expect(
        permission.focusSequence
            == ["openSystemSettings", "openKeyameleon", "pause", "overflow"]
    )
}

@Test("Menu-bar panel VoiceOver announcements stay unique across the surface")
func menuBarPanelVoiceOverAnnouncementsStayUnique() {
    let content = MenuBarPanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [
            assignedKeyboard(name: "Desk", id: "desk", isActive: true),
            assignedKeyboard(
                name: "Travel",
                id: "travel",
                connection: .disconnected,
                inputSource: "com.example.gone"
            ),
        ],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "desk"): .available(name: "U.S."),
            PhysicalKeyboardRecordID(rawValue: "travel"): .unavailable(savedName: nil),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: true,
        marketingVersion: "0.1.0"
    )
    let spoken = content.accessibilityAnnouncements.map(\.spoken)

    #expect(content.accessibilityAnnouncements.contains { announcement in
        announcement.label == "Switching Status" && announcement.value == "Permission Required"
    })
    #expect(content.accessibilityAnnouncements.contains { announcement in
        announcement.label == "Desk"
            && announcement.value == "U.S., Active"
    })
    #expect(content.accessibilityAnnouncements.contains { announcement in
        announcement.label == "Travel"
            && announcement.value == "Unavailable Input Source, Disconnected"
            && announcement.hint == "Unavailable Keyboard Assignment"
    })
    #expect(content.accessibilityAnnouncements.contains { announcement in
        announcement.label == "Version" && announcement.value == "0.1.0"
    })
    #expect(Set(spoken).count == spoken.count)
    #expect(content.focusSequence == [
        "openSystemSettings",
        "desk",
        "travel",
        "openKeyameleon",
        "pause",
        "overflow",
    ])
}

@Test("Menu-bar panel chrome replaces glass when Reduce Transparency is on")
func menuBarPanelChromeReplacesGlassWhenReduceTransparencyIsOn() {
    #expect(MenuBarPanelChrome.surface(reduceTransparency: false) == .nativeGlass)
    #expect(MenuBarPanelChrome.surface(reduceTransparency: true) == .opaque)
    #expect(MenuBarPanelChrome.prefersEmphasizedSeparators(increaseContrast: true))
    #expect(!MenuBarPanelChrome.prefersEmphasizedSeparators(increaseContrast: false))
}

@Test("Menu-bar panel live content follows Switching Status and Keyboard Assignments")
func menuBarPanelLiveContentFollowsSwitchingStatusAndAssignments() {
    let before = MenuBarPanelContent.fixture(outcome: .readyFixture())
    let after = MenuBarPanelContent(
        outcome: .pausedFixture(),
        physicalKeyboards: [assignedKeyboard(name: "Desk", id: "desk")],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "desk"): .available(name: "U.S."),
        ],
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false,
        marketingVersion: "0.1.0"
    )

    #expect(before.quickActions.map(\.id) == [.openKeyameleon, .pause])
    #expect(before.assignmentRows.isEmpty)
    #expect(after.quickActions.map(\.id) == [.openKeyameleon, .resume])
    #expect(after.assignmentRows.map(\.physicalKeyboardName) == ["Desk"])
}

private extension MenuBarPanelContent {
    static func fixture(
        outcome: ActivityTriggeredSwitchingOutcome = .readyFixture(),
        canCheckForUpdates: Bool = true,
        hasPendingUncleanExitNotice: Bool = false,
        marketingVersion: String = "0.1.0"
    ) -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: outcome,
            physicalKeyboards: [],
            assignedInputSources: [:],
            canCheckForUpdates: canCheckForUpdates,
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice,
            marketingVersion: marketingVersion
        )
    }
}

private extension ActivityTriggeredSwitchingOutcome {
    static func readyFixture() -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .ready,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.pause, .openSystemSettings, .checkAgain]
        )
    }

    static func pausedFixture() -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .paused,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.resume]
        )
    }

    static func permissionRequiredFixture() -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .permissionRequired,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.pause, .openSystemSettings, .checkAgain, .requestPermission]
        )
    }

    static func temporarilyUnavailableFixture(
        reason: SwitchingUnavailableReason
    ) -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .temporarilyUnavailable,
            temporarilyUnavailableReasons: [reason],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.pause]
        )
    }
}

private func assignedKeyboard(
    name: String,
    id: String,
    connection: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false,
    inputSource: String = "com.example.us"
) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: id),
        productName: name,
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: inputSource)!),
        connectedServiceCount: connection == .connected ? 1 : 0,
        connectionState: connection,
        isActive: isActive
    )
}

private func unassignedKeyboard(name: String, id: String) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: id),
        productName: name,
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unassigned,
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
}
