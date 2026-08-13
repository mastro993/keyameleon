import Foundation
import Testing
@testable import Keyameleon

@Test("Ready Quick Actions are Open Keyameleon and Pause, with no recovery banner")
@MainActor
func menuBarPanelReadyShowsOpenAndPauseWithoutBanner() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.quickActions.openKeyameleon.title == "Open Keyameleon")
    #expect(content.quickActions.openKeyameleon.id == .openKeyameleon)
    #expect(content.quickActions.pauseOrResume.title == "Pause")
    #expect(content.quickActions.pauseOrResume.id == .pause)
    #expect(content.recoveryBanner == nil)
    #expect(content.actionTitles.contains("Continue Setup…") == false)
}

@Test("Paused Quick Actions show Resume and hide the recovery banner")
@MainActor
func menuBarPanelPausedShowsResumeWithoutBanner() {
    let content = makeMenuBarPanelContent(outcome: .pausedFixture())

    #expect(content.quickActions.openKeyameleon.title == "Open Keyameleon")
    #expect(content.quickActions.pauseOrResume.title == "Resume")
    #expect(content.quickActions.pauseOrResume.id == .resume)
    #expect(content.recoveryBanner == nil)
}

@Test("Permission Required shows a recovery banner with applicable actions")
@MainActor
func menuBarPanelPermissionRequiredShowsRecoveryBanner() throws {
    let content = makeMenuBarPanelContent(outcome: .permissionRequiredFixture())
    let banner = try #require(content.recoveryBanner)

    #expect(banner.statusName == "Permission Required")
    #expect(banner.recoveryActions.map(\.id) == [.openSystemSettings, .checkAgain])
    #expect(banner.recoveryActions.map(\.title) == ["Open System Settings", "Check Again"])
    #expect(content.quickActions.openKeyameleon.id == .openKeyameleon)
    #expect(content.quickActions.pauseOrResume.id == .pause)
}

@Test("Temporarily Unavailable shows a recovery banner without actions")
@MainActor
func menuBarPanelTemporarilyUnavailableShowsBannerWithoutActions() throws {
    let content = makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture())
    let banner = try #require(content.recoveryBanner)

    #expect(banner.statusName == "Temporarily Unavailable")
    #expect(banner.detailLines.contains("Detected reason: macOS is asleep"))
    #expect(
        banner.detailLines.contains(
            "Resumes automatically when macOS allows Activity-Triggered Switching."
        )
    )
    #expect(banner.recoveryActions.isEmpty)
    #expect(content.quickActions.openKeyameleon.id == .openKeyameleon)
    #expect(content.quickActions.pauseOrResume.id == .pause)
}

@Test("Recovery actions appear in the banner only when the outcome offers them")
@MainActor
func menuBarPanelRecoveryActionsFollowOutcomeAvailability() throws {
    let withoutRecovery = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(availableActions: [.pause])
    )
    let banner = try #require(withoutRecovery.recoveryBanner)
    #expect(banner.recoveryActions.isEmpty)

    let withCheckAgain = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(availableActions: [.pause, .checkAgain])
    )
    let checkAgainBanner = try #require(withCheckAgain.recoveryBanner)
    #expect(checkAgainBanner.recoveryActions.map(\.id) == [.checkAgain])
}

@Test("Pause and Resume keep the panel open; Open Keyameleon dismisses it")
@MainActor
func menuBarPanelQuickActionsDismissal() {
    let ready = makeMenuBarPanelContent(outcome: .readyFixture())
    #expect(ready.quickActions.openKeyameleon.closesPanel)
    #expect(ready.quickActions.pauseOrResume.closesPanel == false)

    let paused = makeMenuBarPanelContent(outcome: .pausedFixture())
    #expect(paused.quickActions.pauseOrResume.closesPanel == false)

    let permission = makeMenuBarPanelContent(outcome: .permissionRequiredFixture())
    #expect(permission.recoveryBanner?.recoveryActions.first { $0.id == .openSystemSettings }?.closesPanel == true)
    #expect(permission.recoveryBanner?.recoveryActions.first { $0.id == .checkAgain }?.closesPanel == false)
}

@Test("Footer shows Version from the marketing version and omits the build number")
@MainActor
func menuBarPanelFooterShowsMarketingVersion() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        marketingVersion: "0.1.0"
    )

    #expect(content.footer.versionText == "Version 0.1.0")
    #expect(content.footer.versionText.contains("(") == false)
}

@Test("Footer version falls back when the marketing version is missing or blank")
@MainActor
func menuBarPanelFooterVersionFallback() {
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: nil)
            .footer.versionText == "Version —"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "   ")
            .footer.versionText == "Version —"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "")
            .footer.versionText == "Version —"
    )
}

@Test("Footer overflow contains Settings, Check for Updates, and Quit")
@MainActor
func menuBarPanelFooterOverflowDefaultActions() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        canCheckForUpdates: false
    )

    #expect(
        content.footer.overflowActions.map(\.id)
            == [.settings, .checkForUpdates, .quit]
    )
    #expect(content.footer.overflowActions.map(\.title) == [
        "Settings…",
        "Check for Updates…",
        "Quit Keyameleon",
    ])
    #expect(content.footer.overflowActions.map(\.closesPanel) == [true, true, true])
    #expect(content.footer.overflowActions.first { $0.id == .checkForUpdates }?.isEnabled == false)
}

@Test("Footer overflow includes Review Diagnostics only when an unclean-exit notice is pending")
@MainActor
func menuBarPanelFooterOverflowConditionalReviewDiagnostics() {
    let withoutNotice = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        hasPendingUncleanExitNotice: false
    )
    #expect(withoutNotice.footer.overflowActions.map(\.id).contains(.reviewDiagnostics) == false)
    #expect(withoutNotice.uncleanExitNotice == nil)

    let withNotice = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        hasPendingUncleanExitNotice: true
    )
    #expect(
        withNotice.footer.overflowActions.map(\.id)
            == [.settings, .checkForUpdates, .reviewDiagnostics, .quit]
    )
    #expect(withNotice.footer.overflowActions.first { $0.id == .reviewDiagnostics }?.closesPanel == true)
    #expect(withNotice.uncleanExitNotice?.title == "Keyameleon did not exit cleanly.")
    #expect(withNotice.uncleanExitNotice?.dismiss.id == .dismissDiagnosticsNotice)
    #expect(withNotice.uncleanExitNotice?.dismiss.closesPanel == false)
}

@Test("Incomplete setup continues through Open Keyameleon with no Continue Setup action")
@MainActor
func menuBarPanelIncompleteSetupUsesOpenKeyameleon() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.quickActions.openKeyameleon.title == "Open Keyameleon")
    #expect(content.actionTitles.contains("Continue Setup…") == false)
    #expect(content.actionTitles.contains("Continue Setup") == false)
}

@Test("Menu-bar panel still shows Active Physical Keyboard until assignment rows replace it")
@MainActor
func menuBarPanelShowsNoActivityObservedYetUntilActivation() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())
    let activeTitle = content.statusTitles.first { $0.hasPrefix("Active Physical Keyboard:") }

    #expect(activeTitle == "Active Physical Keyboard: No activity observed yet")
}

private func makeMenuBarPanelContent(
    outcome: ActivityTriggeredSwitchingOutcome,
    actionConditions: [PhysicalKeyboardActionCondition] = [],
    canCheckForUpdates: Bool = true,
    hasPendingUncleanExitNotice: Bool = false,
    marketingVersion: String? = "0.1.0"
) -> MenuBarPanelContent {
    MenuBarPanelContent(
        outcome: outcome,
        actionConditions: actionConditions,
        canCheckForUpdates: canCheckForUpdates,
        hasPendingUncleanExitNotice: hasPendingUncleanExitNotice,
        marketingVersion: marketingVersion
    )
}

private extension ActivityTriggeredSwitchingOutcome {
    static func readyFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .ready,
            availableActions: [.pause, .openSystemSettings, .checkAgain]
        )
    }

    static func pausedFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(switchingStatus: .paused, availableActions: [.resume])
    }

    static func permissionRequiredFixture(
        availableActions: Set<ActivityTriggeredSwitchingAction> = [
            .pause, .openSystemSettings, .checkAgain,
        ]
    ) -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .permissionRequired,
            availableActions: availableActions
        )
    }

    static func temporarilyUnavailableFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .temporarilyUnavailable,
            temporarilyUnavailableReasons: [.sleeping],
            availableActions: [.pause]
        )
    }

    static func fixture(
        switchingStatus: SwitchingStatus,
        temporarilyUnavailableReasons: [SwitchingUnavailableReason] = [],
        availableActions: Set<ActivityTriggeredSwitchingAction>
    ) -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: switchingStatus,
            temporarilyUnavailableReasons: temporarilyUnavailableReasons,
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: availableActions
        )
    }
}
