import AppKit
import Foundation
import Testing
import SwiftUI
@testable import Keyameleon

@Test("Input Source differs notice names the Active Physical Keyboard")
@MainActor
func menuBarPanelMismatchNoticeNamesActivePhysicalKeyboard() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: ActivityTriggeredSwitchingActivePhysicalKeyboard(
            name: "Travel",
            connectionState: .connected,
            assignment: .assigned(name: "U.S.")
        ),
        currentKeyboardAssignment: .assigned(name: "U.S."),
        currentInputSourceName: "Italian",
        mismatch: ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S."),
        warnings: [],
        availableActions: [.pause]
    )
    let notice = makeMenuBarPanelContent(outcome: outcome).notice

    #expect(notice?.title == "Input source differs")
    #expect(notice?.detail == "Travel is using Italian instead of U.S.")
    #expect(notice?.action.id == .settings)
}

@Test("Input Source Hold notice explains its end and offers Switch Back Now instead of the mismatch")
@MainActor
func menuBarPanelHoldNoticeOffersSwitchBackNow() {
    func outcome(hold: ExternalChangeResponse?, currentName: String? = "Italian") -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .ready,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: ActivityTriggeredSwitchingActivePhysicalKeyboard(
                name: "Travel",
                connectionState: .connected,
                assignment: .assigned(name: "U.S.")
            ),
            currentKeyboardAssignment: .assigned(name: "U.S."),
            currentInputSourceName: currentName,
            mismatch: ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S."),
            warnings: [],
            availableActions: [.pause],
            inputSourceHold: hold
        )
    }

    let keyboardChange = makeMenuBarPanelContent(outcome: outcome(hold: .holdUntilKeyboardChange)).notice
    #expect(keyboardChange?.title == "Input source kept")
    #expect(keyboardChange?.detail == "Italian stays until you type on another keyboard or switch apps.")
    #expect(keyboardChange?.action == .init(id: .switchBackNow, title: "Switch Back Now", isEnabled: true))
    #expect(keyboardChange?.tone == .neutral)

    let match = makeMenuBarPanelContent(outcome: outcome(hold: .holdUntilMatch, currentName: nil)).notice
    #expect(match?.detail == "The input source stays until you type on a keyboard assigned to it or switch apps.")
    #expect(match?.action.id == .switchBackNow)

    #expect(makeMenuBarPanelContent(outcome: outcome(hold: nil)).notice?.title == "Input source differs")
    #expect(MenuBarPanelActionID.switchBackNow.shortcut == nil)
}

@Test("Input Source differs notice omits a missing Active Physical Keyboard name")
@MainActor
func menuBarPanelMismatchNoticeOmitsMissingActivePhysicalKeyboardName() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .assigned(name: "U.S."),
        currentInputSourceName: "Italian",
        mismatch: ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S."),
        warnings: [],
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Using Italian instead of U.S.")
}

@Test("Input Source differs notice does not double the period in an Input Source name")
@MainActor
func menuBarPanelMismatchNoticeDoesNotDoublePunctuation() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: ActivityTriggeredSwitchingActivePhysicalKeyboard(
            name: "Travel",
            connectionState: .connected,
            assignment: .assigned(name: "Italian")
        ),
        currentKeyboardAssignment: .assigned(name: "Italian"),
        currentInputSourceName: "U.S.",
        mismatch: ActivityTriggeredSwitchingMismatch(currentName: "U.S.", assignedName: "Italian"),
        warnings: [],
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Travel is using U.S. instead of Italian.")
}

@Test("Retry Now is the only selection-failure notice action")
@MainActor
func menuBarPanelSelectionFailureNoticeOffersRetryWhenAvailable() throws {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: nil,
        mismatch: nil,
        warnings: [
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: "Travel",
                category: .selectionFailed,
                recoveryAction: .retryNow
            )
        ],
        availableActions: [.pause, .retryNow]
    )
    let content = makeMenuBarPanelContent(outcome: outcome)
    let action = try #require(content.notice?.action)

    #expect(content.notice?.title == "Couldn’t switch input source")
    #expect(content.notice?.detail == "Try again for Travel.")
    #expect(action.id == .retryNow)
    #expect(action.title == "Retry Now")
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
}

@Test("Selection-failure notice opens Settings when Retry Now is unavailable")
@MainActor
func menuBarPanelSelectionFailureNoticeFallsBackToSettings() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: nil,
        mismatch: nil,
        warnings: [
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: nil,
                category: .selectionFailed,
                recoveryAction: .retryNow
            )
        ],
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Check the input source in Settings.")
    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.action.id == .settings)
}

@Test("Unassigned keyboard notice names one unassigned Physical Keyboard")
@MainActor
func menuBarPanelUnassignedNoticeUsesKeyboardName() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.title == "Keyboard not assigned")
    #expect(content.notice?.detail == "Choose an input source for Travel.")
    #expect(content.notice?.action.id == .settings)
}

@Test("Unassigned keyboard notice preserves Physical Keyboard order")
@MainActor
func menuBarPanelUnassignedNoticePreservesKeyboardOrder() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned),
            makePanelKeyboard(name: "Desk", identifier: "desk", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.detail == "Choose input sources for Travel and Desk.")
}

@Test("Unassigned keyboard notice counts three unassigned Physical Keyboards")
@MainActor
func menuBarPanelUnassignedNoticeCountsThreePhysicalKeyboards() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned),
            makePanelKeyboard(name: "Desk", identifier: "desk", assignmentState: .unassigned),
            makePanelKeyboard(name: "Studio", identifier: "studio", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.detail == "Choose input sources for 3 keyboards.")
}

@Test("Unavailable Keyboard Assignment stays on assignment row without a notice")
@MainActor
func menuBarPanelUnavailableAssignmentDoesNotCreateNotice() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")]
    )

    #expect(content.assignmentList.rows.first?.warningNote == MenuBarAssignmentList.unavailableNote)
    #expect(content.notice == nil)
}

@Test("Permission Required notice outranks unassigned Physical Keyboards")
@MainActor
func menuBarPanelNoticePrioritizesPermissionOverUnassignedKeyboard() {
    let content = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.title == "Input Monitoring required")
}

@Test("Selection failure notice outranks mismatch and unassigned conditions")
@MainActor
func menuBarPanelNoticePrioritizesSelectionFailure() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: "Italian",
        mismatch: ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S."),
        warnings: [
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: "Travel",
                category: .selectionFailed,
                recoveryAction: .retryNow
            )
        ],
        availableActions: [.pause]
    )
    let content = makeMenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.title == "Couldn’t switch input source")
    #expect(content.notice?.detail == "Check Travel’s input source in Settings.")
}

@Test("Input Source mismatch notice outranks unassigned")
@MainActor
func menuBarPanelNoticePrioritizesMismatch() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .ready,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .assigned(name: "U.S."),
        currentInputSourceName: "Italian",
        mismatch: ActivityTriggeredSwitchingMismatch(currentName: "Italian", assignedName: "U.S."),
        warnings: [],
        availableActions: [.pause]
    )
    let content = makeMenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.title == "Input source differs")
}

@Test("Ready with every keyboard assigned shows no notice")
@MainActor
func menuBarPanelReadyWithoutConditionsHasNoNotice() {
    #expect(makeMenuBarPanelContent(outcome: .readyFixture()).notice == nil)
}
