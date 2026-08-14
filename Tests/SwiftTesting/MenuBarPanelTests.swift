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
    #expect(banner.recoveryActions.map(\.id) == [
        .requestPermission, .openSystemSettings, .checkAgain,
    ])
    #expect(banner.recoveryActions.map(\.title) == [
        "Request Permission", "Open System Settings", "Check Again",
    ])
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
    #expect(
        permission.recoveryBanner?.recoveryActions.first { $0.id == .requestPermission }?.closesPanel
            == true
    )
    #expect(
        permission.recoveryBanner?.recoveryActions.first { $0.id == .openSystemSettings }?.closesPanel
            == true
    )
    #expect(
        permission.recoveryBanner?.recoveryActions.first { $0.id == .checkAgain }?.closesPanel
            == false
    )
}

@Test("Footer shows Keyameleon from the marketing version and omits the build number")
@MainActor
func menuBarPanelFooterShowsMarketingVersion() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        marketingVersion: "0.1.0"
    )

    #expect(content.footer.versionText == "Keyameleon 0.1.0")
    #expect(content.footer.versionText.contains("(") == false)
}

@Test("Footer version falls back when the marketing version is missing or blank")
@MainActor
func menuBarPanelFooterVersionFallback() {
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: nil)
            .footer.versionText == "Keyameleon —"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "   ")
            .footer.versionText == "Keyameleon —"
    )
    #expect(
        makeMenuBarPanelContent(outcome: .readyFixture(), marketingVersion: "")
            .footer.versionText == "Keyameleon —"
    )
}

@Test("Dismissing More without a selection closes the menu-bar panel")
func menuBarOverflowOutsideClickClosesPanel() {
    #expect(
        MenuBarOverflowMenuDismissal.shouldClosePanelAfterMenuDismiss(didSelectItem: false)
    )
    #expect(
        MenuBarOverflowMenuDismissal.shouldClosePanelAfterMenuDismiss(didSelectItem: true)
            == false
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

@Test("Menu-bar assignment list heading has no app name or assignment count")
func menuBarAssignmentListUsesCompactHeading() {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
        ],
        assignedInputSourceNames: [
            PhysicalKeyboardRecordID(rawValue: "travel"): "Italian"
        ]
    )

    #expect(list.heading == "Keyboards")
    #expect(list.heading.contains("Keyameleon") == false)
    #expect(list.heading.contains("1") == false)
}

@Test("Menu-bar assignment pill uses Physical Keyboard Name and assigned Input Source")
func menuBarAssignmentPillUsesPhysicalKeyboardNameAndAssignedInputSource() throws {
    let renamed = makeAssignedPanelKeyboard(
        name: "Keychron K2",
        identifier: "k2",
        customName: "Travel"
    )
    let list = MenuBarAssignmentList(
        physicalKeyboards: [renamed],
        assignedInputSourceNames: panelNames("k2", "Italian")
    )
    let travel = try #require(list.rows.first { $0.id == "k2" })

    #expect(travel.physicalKeyboardName == "Travel")
    #expect(travel.assignedInputSourceName == "Italian")
}

@Test("Menu-bar assignment list shows only Physical Keyboards with Keyboard Assignments")
func menuBarAssignmentListShowsOnlyAssignedPhysicalKeyboards() throws {
    let assigned = makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
    let unassigned = makePanelKeyboard(
        name: "Studio",
        identifier: "studio",
        assignmentState: .unassigned
    )
    let unsupported = makePanelKeyboard(
        name: "Shared",
        identifier: "shared",
        assignmentState: .unsupported(.sharedIdentity)
    )
    let list = MenuBarAssignmentList(
        physicalKeyboards: [unassigned, assigned, unsupported],
        assignedInputSourceNames: [
            PhysicalKeyboardRecordID(rawValue: "travel"): "Italian"
        ]
    )
    let row = try #require(list.rows.first)

    #expect(list.rows.count == 1)
    #expect(row.physicalKeyboardName == "Travel")
    #expect(row.assignedInputSourceName == "Italian")
}

@Test("Menu-bar assignment list orders Active, connected, then disconnected by name")
func menuBarAssignmentListOrdersActiveConnectedThenDisconnected() {
    let zebra = makeAssignedPanelKeyboard(
        name: "Zebra",
        identifier: "zebra",
        connectionState: .connected
    )
    let active = makeAssignedPanelKeyboard(
        name: "Later Active",
        identifier: "active",
        connectionState: .connected,
        isActive: true
    )
    let apple = makeAssignedPanelKeyboard(
        name: "Apple",
        identifier: "apple",
        connectionState: .connected
    )
    let zeta = makeAssignedPanelKeyboard(
        name: "Zeta",
        identifier: "zeta",
        connectionState: .disconnected
    )
    let desk = makeAssignedPanelKeyboard(
        name: "Desk",
        identifier: "desk",
        connectionState: .disconnected
    )
    let list = MenuBarAssignmentList(
        physicalKeyboards: [zeta, zebra, desk, apple, active],
        assignedInputSourceNames: panelNames(
            "active", "Later",
            "apple", "US",
            "zebra", "Italian",
            "desk", "French",
            "zeta", "German"
        )
    )

    #expect(list.rows.map(\.physicalKeyboardName) == [
        "Later Active",
        "Apple",
        "Zebra",
        "Desk",
        "Zeta"
    ])
}

@Test("Menu-bar assignment rows use distinct accessible marks and dim disconnected")
func menuBarAssignmentRowsUseDistinctMarksAndDimDisconnected() throws {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(
                name: "Active Board",
                identifier: "active",
                isActive: true
            ),
            makeAssignedPanelKeyboard(name: "Connected Board", identifier: "connected"),
            makeAssignedPanelKeyboard(
                name: "Away Board",
                identifier: "away",
                connectionState: .disconnected
            )
        ],
        assignedInputSourceNames: panelNames(
            "active", "Italian",
            "connected", "US",
            "away", "French"
        )
    )
    let active = try #require(list.rows.first { $0.physicalKeyboardName == "Active Board" })
    let connected = try #require(list.rows.first { $0.physicalKeyboardName == "Connected Board" })
    let disconnected = try #require(list.rows.first { $0.physicalKeyboardName == "Away Board" })

    #expect(active.connectionMark == .active)
    #expect(active.isActive)
    #expect(active.accessibilityMark == "Active")
    #expect(active.isDimmed == false)
    #expect(connected.connectionMark == .connected)
    #expect(connected.accessibilityMark == "Connected")
    #expect(connected.isDimmed == false)
    #expect(disconnected.connectionMark == .disconnected)
    #expect(disconnected.accessibilityMark == "Disconnected")
    #expect(disconnected.isDimmed)
}

@Test("Unavailable Keyboard Assignment keeps the saved row and shows Unavailable Input Source")
func menuBarAssignmentListKeepsUnavailableAssignmentWithoutDroppingTheRow() throws {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
        ],
        assignedInputSourceNames: [:]
    )
    let row = try #require(list.rows.first)

    #expect(list.rows.count == 1)
    #expect(row.physicalKeyboardName == "Travel")
    #expect(row.assignedInputSourceName == "Unavailable Input Source")
    #expect(row.showsWarningSymbol)
    #expect(row.warningNote == "Unavailable Keyboard Assignment")
}

@Test("Menu-bar assignment rows warn only when action is needed")
func menuBarAssignmentRowsWarnOnlyWhenActionIsNeeded() throws {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(name: "Ready", identifier: "ready"),
            makeAssignedPanelKeyboard(name: "Broken", identifier: "broken")
        ],
        assignedInputSourceNames: [
            PhysicalKeyboardRecordID(rawValue: "ready"): "Italian"
        ]
    )
    let ready = try #require(list.rows.first { $0.physicalKeyboardName == "Ready" })
    let broken = try #require(list.rows.first { $0.physicalKeyboardName == "Broken" })

    #expect(ready.showsWarningSymbol == false)
    #expect(ready.warningNote == nil)
    #expect(broken.showsWarningSymbol)
    #expect(broken.warningNote == "Unavailable Keyboard Assignment")
}

@Test("Menu-bar assignment list empty state is compact")
func menuBarAssignmentListEmptyStateIsCompact() {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makePanelKeyboard(name: "Studio", identifier: "studio", assignmentState: .unassigned)
        ],
        assignedInputSourceNames: [:]
    )

    #expect(list.rows.isEmpty)
    #expect(list.emptyTitle == "No assigned keyboards")
    #expect(list.emptyDescription == "Open Keyameleon Settings to assign keyboards.")
    #expect(list.scrolls == false)
}

@Test("Menu-bar assignment list scrolls only after five rows")
func menuBarAssignmentListScrollsOnlyAfterFiveRows() {
    let five = MenuBarAssignmentList(
        physicalKeyboards: (1...5).map { index in
            makeAssignedPanelKeyboard(name: "Board \(index)", identifier: "board-\(index)")
        },
        assignedInputSourceNames: Dictionary(
            uniqueKeysWithValues: (1...5).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), "US")
            }
        )
    )
    let six = MenuBarAssignmentList(
        physicalKeyboards: (1...6).map { index in
            makeAssignedPanelKeyboard(name: "Board \(index)", identifier: "board-\(index)")
        },
        assignedInputSourceNames: Dictionary(
            uniqueKeysWithValues: (1...6).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), "US")
            }
        )
    )

    #expect(MenuBarAssignmentList.visibleRowLimit == 5)
    #expect(five.rows.count == 5)
    #expect(five.scrolls == false)
    #expect(six.rows.count == 6)
    #expect(six.scrolls)
}

@Test("Menu-bar assignment list keeps every assigned row")
func menuBarAssignmentListKeepsEveryAssignedRow() {
    let count = 64
    let list = MenuBarAssignmentList(
        physicalKeyboards: (1...count).map { index in
            makeAssignedPanelKeyboard(name: "Board \(index)", identifier: "board-\(index)")
        },
        assignedInputSourceNames: Dictionary(
            uniqueKeysWithValues: (1...count).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), "US")
            }
        )
    )

    #expect(list.rows.count == count)
    #expect(list.scrolls)
}

@Test("Menu-bar panel content keeps Keyboards heading, empty copy, and Quick Actions")
@MainActor
func menuBarPanelContentKeepsAssignmentListAndQuickActions() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.assignmentList.heading == "Keyboards")
    #expect(content.assignmentList.emptyTitle == "No assigned keyboards")
    #expect(content.assignmentList.emptyDescription == "Open Keyameleon Settings to assign keyboards.")
    #expect(content.assignmentList.rows.isEmpty)
    #expect(content.recoveryBanner == nil)
    #expect(content.quickActions.openKeyameleon.title == "Open Keyameleon")
    #expect(content.quickActions.pauseOrResume.title == "Pause")
    #expect(content.footer.overflowActions.map(\.id) == [.settings, .checkForUpdates, .quit])
}

@Test("Menu-bar panel assignment rows stay read-only")
@MainActor
func menuBarPanelAssignmentRowsStayReadOnly() throws {
    let keyboard = makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [keyboard],
        assignedInputSourceNames: [
            PhysicalKeyboardRecordID(rawValue: "travel"): "Italian"
        ]
    )
    let row = try #require(content.assignmentList.rows.first)

    #expect(row.id == "travel")
    #expect(content.assignmentList.rows.count == 1)
    #expect(content.quickActions.openKeyameleon.id == .openKeyameleon)
}

private func makeMenuBarPanelContent(
    outcome: ActivityTriggeredSwitchingOutcome,
    physicalKeyboards: [PhysicalKeyboard] = [],
    assignedInputSourceNames: [PhysicalKeyboardRecordID: String] = [:],
    canCheckForUpdates: Bool = true,
    hasPendingUncleanExitNotice: Bool = false,
    marketingVersion: String? = "0.1.0"
) -> MenuBarPanelContent {
    MenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: physicalKeyboards,
        assignedInputSourceNames: assignedInputSourceNames,
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
            .pause, .requestPermission, .openSystemSettings, .checkAgain,
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

private func panelNames(_ pairs: String...) -> [PhysicalKeyboardRecordID: String] {
    Dictionary(
        uniqueKeysWithValues: stride(from: 0, to: pairs.count, by: 2).map { index in
            (PhysicalKeyboardRecordID(rawValue: pairs[index]), pairs[index + 1])
        }
    )
}

private func makeAssignedPanelKeyboard(
    name: String,
    identifier: String,
    connectionState: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false,
    customName: String? = nil
) -> PhysicalKeyboard {
    makePanelKeyboard(
        name: name,
        identifier: identifier,
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "com.example.us")!),
        connectionState: connectionState,
        isActive: isActive,
        customName: customName
    )
}

private func makePanelKeyboard(
    name: String,
    identifier: String,
    assignmentState: PhysicalKeyboardAssignmentState,
    connectionState: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false,
    customName: String? = nil
) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: identifier),
        productName: name,
        customName: customName,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: assignmentState,
        connectedServiceCount: connectionState == .connected ? 1 : 0,
        connectionState: connectionState,
        isActive: isActive
    )
}
