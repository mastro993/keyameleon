import AppKit
import Foundation
import Testing
import SwiftUI
@testable import Keyameleon

@Test("Ready tray has Pause and no recovery actions")
@MainActor
func menuBarPanelReadyShowsPauseWithoutRecovery() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(overflow(content, .pause)?.title == "Pause Switching")
    #expect(overflowIDs(content).contains(.requestPermission) == false)
    #expect(overflowIDs(content).contains(.relaunch) == false)
}

@Test("Paused tray shows Resume")
@MainActor
func menuBarPanelPausedShowsResume() {
    let content = makeMenuBarPanelContent(outcome: .pausedFixture())

    #expect(overflow(content, .resume)?.title == "Resume Switching")
    #expect(overflowIDs(content).contains(.pause) == false)
}

@Test("Permission Required shows only core menu actions")
@MainActor
func menuBarPanelPermissionRequiredOmitsRecoveryActions() {
    let content = makeMenuBarPanelContent(outcome: .permissionRequiredFixture())

    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
    #expect(content.footer.actions.map(\.title).contains("Request Permission") == false)
    #expect(content.footer.actions.map(\.title).contains("Open System Settings") == false)
    #expect(content.footer.actions.map(\.title).contains("Restart \(AppIdentity.current.name)") == false)
    #expect(overflow(content, .pause)?.id == .pause)
}

@Test("Temporarily Unavailable tray has Pause and no recovery actions")
@MainActor
func menuBarPanelTemporarilyUnavailableHasNoRecoveryActions() {
    let content = makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture())

    #expect(overflow(content, .pause)?.id == .pause)
    #expect(overflowIDs(content).contains(.requestPermission) == false)
    #expect(overflowIDs(content).contains(.openSystemSettings) == false)
    #expect(overflowIDs(content).contains(.relaunch) == false)
}

@Test("Recovery actions never appear in the menu")
@MainActor
func menuBarPanelRecoveryActionsNeverAppear() {
    for outcome in [
        ActivityTriggeredSwitchingOutcome.readyFixture(),
        .permissionRequiredFixture(),
        .temporarilyUnavailableFixture(),
    ] {
        let content = makeMenuBarPanelContent(outcome: outcome)
        #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
        #expect(content.footer.actions.map(\.title).contains("Request Permission") == false)
        #expect(content.footer.actions.map(\.title).contains("Open System Settings") == false)
        #expect(content.footer.actions.map(\.title).contains("Restart \(AppIdentity.current.name)") == false)
    }
}

@Test("Header shows the marketing version with a v prefix and omits the build number")
@MainActor
func menuBarPanelHeaderShowsMarketingVersion() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        marketingVersion: "0.1.0"
    )

    #expect(content.headerTitle == "\(AppIdentity.current.name) v0.1.0")
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: " \n0.1.0\t ")
            .headerTitle == "\(AppIdentity.current.name) v0.1.0"
    )
}

@Test("Header version falls back when the marketing version is missing or blank")
@MainActor
func menuBarPanelHeaderVersionFallback() {
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: nil)
            .headerTitle == "\(AppIdentity.current.name) v—"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "   ")
            .headerTitle == "\(AppIdentity.current.name) v—"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "")
            .headerTitle == "\(AppIdentity.current.name) v—"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .pausedFixture(), marketingVersion: nil)
            .headerTitle == "\(AppIdentity.current.name) v— (Paused)"
    )
}

@Test("Tray actions contain Pause, Settings, Check for Updates, and Quit")
@MainActor
func menuBarPanelFooterOverflowDefaultActions() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
    #expect(content.footer.actions.map(\.title) == [
        "Pause Switching",
        "Settings",
        "Check for Updates…",
        "Quit \(AppIdentity.current.name)",
    ])
}

@Test("Check for Updates sits below Settings in every switching state")
@MainActor
func menuBarPanelPlacesCheckForUpdatesBelowSettings() {
    for outcome in [
        ActivityTriggeredSwitchingOutcome.readyFixture(),
        .permissionRequiredFixture(),
        .temporarilyUnavailableFixture(),
        .pausedFixture()
    ] {
        for canCheckForUpdates in [false, true] {
            let content = makeMenuBarPanelContent(
                outcome: outcome,
                canCheckForUpdates: canCheckForUpdates
            )
            let actions = content.footer.actions
            let settingsIndex = actions.firstIndex { $0.id == .settings }
            #expect(settingsIndex != nil)
            if let settingsIndex {
                #expect(actions[settingsIndex + 1].id == .checkForUpdates)
                #expect(actions[settingsIndex + 1].isEnabled == canCheckForUpdates)
            }
        }
    }
}

@Test("Menu-bar panel content keeps empty copy and Quick Actions")
@MainActor
func menuBarPanelContentKeepsAssignmentListAndQuickActions() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.assignmentList.emptyTitle == "No assigned keyboards")
    #expect(content.assignmentList.emptyDescription == "Assign keyboards in Settings.")
    #expect(content.assignmentList.rows.isEmpty)
    #expect(overflow(content, .pause)?.title == "Pause Switching")
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
}

@Test("Menu-bar panel assignment rows stay read-only")
@MainActor
func menuBarPanelAssignmentRowsStayReadOnly() throws {
    let keyboard = makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [keyboard],
        assignedInputSources: panelNames("travel", "Italian")
    )
    let row = try #require(content.assignmentList.rows.first)

    #expect(row.id == "travel")
    #expect(content.assignmentList.rows.count == 1)
}

@Test("Native menu shortcuts map to Command-P, Command-comma, and Command-Q")
func menuBarPanelCommandShortcutMapping() {
    for id in [MenuBarPanelActionID.pause, .resume] {
        #expect(id.shortcut?.rawValue == "p")
    }
    #expect(MenuBarPanelActionID.settings.shortcut?.rawValue == ",")
    #expect(MenuBarPanelActionID.quit.shortcut?.rawValue == "q")
    for id in [MenuBarPanelActionID.requestPermission, .openSystemSettings,
               .relaunch, .retryNow, .retryPersistence, .checkForUpdates] {
        #expect(id.shortcut == nil)
    }
}
