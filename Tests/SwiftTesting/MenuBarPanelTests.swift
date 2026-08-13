import Foundation
import Testing
@testable import Keyameleon

@Test("Menu-bar panel content keeps Switching Status, Active Physical Keyboard, and actions")
@MainActor
func menuBarPanelContentKeepsStatusAndActions() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        actionConditions: [],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )
    let titles = content.titles

    #expect(titles.contains { $0.hasPrefix("Switching Status:") })
    #expect(titles.contains { $0.hasPrefix("Active Physical Keyboard:") })
    #expect(titles.contains { $0.hasPrefix("Keyboard Assignment:") })
    #expect(titles.contains { $0.hasPrefix("Current Input Source:") })
    #expect(content.actionTitles.contains("Pause Activity-Triggered Switching"))
    #expect(content.actionTitles.contains("Open Keyameleon…"))
    #expect(content.actionTitles.contains("Open System Settings"))
    #expect(content.actionTitles.contains("Check Again"))
    #expect(content.actionTitles.contains("Settings…"))
    #expect(content.actionTitles.contains("Check for Updates…"))
    #expect(content.actionTitles.contains("Quit Keyameleon"))
}

@Test("Menu-bar panel shows no activity observed yet until Activation Activity")
@MainActor
func menuBarPanelShowsNoActivityObservedYetUntilActivation() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        actionConditions: [],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )
    let activeTitle = content.titles.first { $0.hasPrefix("Active Physical Keyboard:") }

    #expect(activeTitle == "Active Physical Keyboard: No activity observed yet")
}

@Test("Menu-bar panel shows Resume when Activity-Triggered Switching is paused")
@MainActor
func menuBarPanelShowsResumeWhenPaused() {
    let content = MenuBarPanelContent(
        outcome: .pausedFixture(),
        actionConditions: [],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )

    #expect(content.titles.contains("Switching Status: Paused"))
    #expect(content.actionTitles.contains("Resume Activity-Triggered Switching"))
    #expect(content.actionTitles.contains("Open Keyameleon…") == true)
    #expect(content.actionTitles.contains("Pause Activity-Triggered Switching") == false)
}

@Test("Menu-bar panel shows dismissible unclean-exit notice and review action")
@MainActor
func menuBarPanelShowsDismissibleUncleanExitNoticeAndReviewAction() {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        actionConditions: [],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: true
    )

    #expect(content.titles.contains("Keyameleon did not exit cleanly."))
    #expect(content.actionTitles.contains("Review Diagnostics…"))
    #expect(content.actionTitles.contains("Dismiss Diagnostics Notice"))
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
}
