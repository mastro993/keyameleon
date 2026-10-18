import AppKit
import Foundation
import Testing
import SwiftUI
@testable import Keyameleon

@Test("Long notice titles and content wrap without widening the native menu")
@MainActor
func menuBarPanelLongNoticeKeepsDefaultWidth() {
    for tone in [MenuBarPanelNotice.Tone.warning, .neutral] {
        let action = MenuBarPanelContent.Action(id: .settings, title: "Open Settings", isEnabled: true)
        let shortHost = NSHostingView(rootView: MenuBarPanelNoticeView(
            notice: MenuBarPanelNotice(title: "Notice", detail: "Short explanation.", action: action, tone: tone),
            perform: { _ in }
        ))
        let longHost = NSHostingView(rootView: MenuBarPanelNoticeView(
            notice: MenuBarPanelNotice(
                title: String(repeating: "Long notice title ", count: 8),
                detail: String(repeating: "Long explanation that must wrap within the menu. ", count: 12),
                action: action,
                tone: tone
            ),
            perform: { _ in }
        ))
        shortHost.frame.size = shortHost.fittingSize
        longHost.frame.size = longHost.fittingSize
        #expect(shortHost.frame.width == Theme.Menu.width)
        #expect(longHost.frame.width == Theme.Menu.width)
        #expect(longHost.frame.height > shortHost.frame.height)

        let shortMenu = NSMenu()
        let shortItem = NSMenuItem()
        shortItem.view = shortHost
        shortMenu.addItem(shortItem)
        let longMenu = NSMenu()
        let longItem = NSMenuItem()
        longItem.view = longHost
        longMenu.addItem(longItem)
        #expect(longMenu.size.width == shortMenu.size.width)
    }
}

@Test("Ready panel without notice conditions has no notice")
@MainActor
func menuBarPanelReadyWithoutNoticeConditionsHasNoNotice() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")],
        assignedInputSources: panelNames("travel", "U.S.")
    )

    #expect(content.notice == nil)
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
}

@Test("An unasked permission notice offers the macOS alert")
@MainActor
func menuBarPanelUnaskedPermissionNoticeRequestsAccess() throws {
    let content = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )
    let action = try #require(content.notice?.action)

    #expect(content.notice?.title == "Input Monitoring required")
    #expect(content.notice?.tone == .warning)
    #expect(action.id == .requestPermission)
    #expect(action.title == "Allow Input Monitoring…")
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
}

@Test("A denied permission notice opens System Settings and offers Restart")
@MainActor
func menuBarPanelDeniedPermissionNoticeOpensSettingsAndOffersRestart() throws {
    let content = makeMenuBarPanelContent(outcome: .permissionDeniedFixture())
    let action = try #require(content.notice?.action)

    #expect(content.notice?.title == "Input Monitoring is off")
    #expect(content.notice?.tone == .warning)
    #expect(action.id == .openSystemSettings)
    #expect(action.title == "Open System Settings")
    #expect(overflowIDs(content) == [.pause, .relaunch, .settings, .checkForUpdates, .quit])
    #expect(overflow(content, .relaunch)?.title == "Restart \(AppIdentity.current.name)")
    #expect(content.footer.actions.map(\.title).contains("Open System Settings") == false)
}

@Test("Only the Permission Required notice carries the warning tone")
@MainActor
func menuBarPanelOnlyPermissionRequiredUsesWarningTone() {
    #expect(makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture()).notice?.tone == .neutral)
    #expect(
        makeMenuBarPanelContent(
            outcome: .readyFixture(),
            physicalKeyboards: [
                makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
            ]
        ).notice?.tone == .neutral
    )
}

@Test("Permission Required notice opens Settings when recovery actions are unavailable")
@MainActor
func menuBarPanelPermissionNoticeFallsBackToSettings() {
    let outcome = ActivityTriggeredSwitchingOutcome.permissionRequiredFixture(
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.action.id == .settings)
}

@Test("Temporarily Unavailable explains sleeping and keeps Pause in footer")
@MainActor
func menuBarPanelTemporarilyUnavailableNoticeExplainsSleeping() {
    let content = makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture())

    #expect(content.notice?.detail == "The Mac is sleeping. Switching resumes automatically.")
    #expect(content.notice?.action.id == .settings)
    #expect(overflowIDs(content).contains(.pause))
}

@Test("Temporarily Unavailable reason priority ignores input order")
@MainActor
func menuBarPanelTemporarilyUnavailableNoticeUsesReasonPriority() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .temporarilyUnavailable,
        temporarilyUnavailableReasons: [.secureInput, .sleeping],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: nil,
        mismatch: nil,
        warnings: [],
        availableActions: [.pause]
    )
    let content = makeMenuBarPanelContent(outcome: outcome)

    #expect(content.notice?.detail == "The Mac is sleeping. Switching resumes automatically.")
}

@Test("Temporarily Unavailable reason copy covers lock, Secure Input, and protected data")
@MainActor
func menuBarPanelTemporarilyUnavailableNoticeExplainsEveryReason() {
    let cases: [([SwitchingUnavailableReason], String)] = [
        ([.secureInput, .inactiveSession], "The session is locked."),
        ([.secureInput, .protectedDataUnavailable], "Secure Input is active."),
        ([.protectedDataUnavailable], "Protected data is unavailable.")
    ]

    for (reasons, reason) in cases {
        let outcome = ActivityTriggeredSwitchingOutcome(
            switchingStatus: .temporarilyUnavailable,
            temporarilyUnavailableReasons: reasons,
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.pause]
        )
        let content = makeMenuBarPanelContent(outcome: outcome)

        #expect(content.notice?.detail == "\(reason) Switching resumes automatically.")
    }
}

@Test("Temporarily Unavailable without a known reason explains automatic recovery")
@MainActor
func menuBarPanelTemporarilyUnavailableNoticeWithoutKnownReasonExplainsAutomaticRecovery() {
    let outcome = ActivityTriggeredSwitchingOutcome(
        switchingStatus: .temporarilyUnavailable,
        temporarilyUnavailableReasons: [],
        activePhysicalKeyboard: nil,
        currentKeyboardAssignment: .none,
        currentInputSourceName: nil,
        mismatch: nil,
        warnings: [],
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Switching resumes automatically.")
}

@Test("Paused panel marks the title and shows no notice")
@MainActor
func menuBarPanelPausedMarksTitleWithoutNotice() {
    let content = makeMenuBarPanelContent(outcome: .pausedFixture())

    #expect(content.headerTitle == "\(AppIdentity.current.name) v0.1.0 (Paused)")
    #expect(content.notice == nil)
    #expect(overflow(content, .resume)?.title == "Resume Switching")
}

@Test("Paused suffix appears only while switching is paused")
@MainActor
func menuBarPanelPausedSuffixAppearsOnlyWhilePaused() {
    #expect(makeMenuBarPanelContent(outcome: .readyFixture()).headerTitle == "\(AppIdentity.current.name) v0.1.0")
    #expect(makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture()).headerTitle == "\(AppIdentity.current.name) v0.1.0")
    #expect(makeMenuBarPanelContent(outcome: .permissionRequiredFixture()).headerTitle == "\(AppIdentity.current.name) v0.1.0")
    #expect(makeMenuBarPanelContent(outcome: .pausedFixture()).headerTitle == "\(AppIdentity.current.name) v0.1.0 (Paused)")
}
