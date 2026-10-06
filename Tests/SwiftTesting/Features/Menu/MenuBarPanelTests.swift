import Foundation
import Testing
import SwiftUI
@testable import Keyameleon

@Test("Ready tray has Pause and no recovery actions")
@MainActor
func menuBarPanelReadyShowsPauseWithoutRecovery() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.footer.about.title == "About Keyameleon")
    #expect(content.footer.about.id == .about)
    #expect(overflow(content, .pause)?.title == "Pause Switching")
    #expect(overflowIDs(content).contains(.requestPermission) == false)
    #expect(overflowIDs(content).contains(.checkAgain) == false)
    #expect(content.actionTitles.contains("Continue Setup…") == false)
}

@Test("Paused tray shows Resume")
@MainActor
func menuBarPanelPausedShowsResume() {
    let content = makeMenuBarPanelContent(outcome: .pausedFixture())

    #expect(content.footer.about.id == .about)
    #expect(overflow(content, .resume)?.title == "Resume Switching")
    #expect(overflowIDs(content).contains(.pause) == false)
}

@Test("Permission Required shows only core menu actions")
@MainActor
func menuBarPanelPermissionRequiredOmitsRecoveryActions() {
    let content = makeMenuBarPanelContent(outcome: .permissionRequiredFixture())

    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
    #expect(content.actionTitles.contains("Request Permission") == false)
    #expect(content.actionTitles.contains("Open System Settings") == false)
    #expect(content.actionTitles.contains("Check Again") == false)
    #expect(overflow(content, .pause)?.id == .pause)
}

@Test("Temporarily Unavailable tray has Pause and no recovery actions")
@MainActor
func menuBarPanelTemporarilyUnavailableHasNoRecoveryActions() {
    let content = makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture())

    #expect(overflow(content, .pause)?.id == .pause)
    #expect(overflowIDs(content).contains(.requestPermission) == false)
    #expect(overflowIDs(content).contains(.openSystemSettings) == false)
    #expect(overflowIDs(content).contains(.checkAgain) == false)
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
        #expect(content.actionTitles.contains("Request Permission") == false)
        #expect(content.actionTitles.contains("Open System Settings") == false)
        #expect(content.actionTitles.contains("Check Again") == false)
    }
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

@Test("Header info button opens About and is omitted from action rows")
@MainActor
func menuBarPanelHeaderInfoOpensAbout() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.footer.about.id == .about)
    #expect(content.footer.about.title == "About Keyameleon")
    #expect(content.footer.about.isEnabled)
    #expect(overflowIDs(content).contains(.about) == false)
    #expect(content.actionTitles.contains("About Keyameleon"))
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
        "Quit Keyameleon",
    ])
}

@Test("About action does not add setup actions")
@MainActor
func menuBarPanelAboutOmitsSetupActions() {
    let content = makeMenuBarPanelContent(outcome: .readyFixture())

    #expect(content.footer.about.title == "About Keyameleon")
    #expect(content.actionTitles.contains("Continue Setup…") == false)
    #expect(content.actionTitles.contains("Continue Setup") == false)
}

@Test("Incomplete Guided setup has a continuation in every switching state")
@MainActor
func menuBarPanelOffersGuidedSetupContinuation() {
    for outcome in [
        ActivityTriggeredSwitchingOutcome.readyFixture(),
        .permissionRequiredFixture(),
        .temporarilyUnavailableFixture(),
        .pausedFixture()
    ] {
        let incomplete = makeMenuBarPanelContent(outcome: outcome, isSetupComplete: false)
        let complete = makeMenuBarPanelContent(outcome: outcome, isSetupComplete: true)

        #expect(incomplete.footer.actions.first?.id == .continueSetup)
        #expect(incomplete.footer.actions.map(\.title).contains("Continue Guided Setup"))
        #expect(complete.footer.actions.map(\.title).contains("Continue Guided Setup") == false)
        #expect(complete.notice?.title != "Guided setup is not finished")
        for canCheckForUpdates in [false, true] {
            for isSetupComplete in [false, true] {
                let content = makeMenuBarPanelContent(
                    outcome: outcome,
                    isSetupComplete: isSetupComplete,
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
}

@Test("Menu-bar assignment list heading has no app name or assignment count")
func menuBarAssignmentListUsesCompactHeading() {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
        ],
        assignedInputSources: panelNames("travel", "Italian")
    )

    #expect(list.heading == "Keyboards")
    #expect(list.heading.contains("Keyameleon") == false)
    #expect(list.heading.contains("1") == false)
}

@Test("Menu-bar assignment pill shows Custom name, product name, and locale code")
func menuBarAssignmentPillUsesPhysicalKeyboardNameAndAssignedInputSource() throws {
    let renamed = makeAssignedPanelKeyboard(
        name: "Keychron K2",
        identifier: "k2",
        customName: "Travel"
    )
    let untouched = makeAssignedPanelKeyboard(name: "HHKB Professional", identifier: "desk")
    let list = MenuBarAssignmentList(
        physicalKeyboards: [renamed, untouched],
        assignedInputSources: [
            PhysicalKeyboardRecordID(rawValue: "k2"): EligibleInputSource(
                identifier: "com.apple.keylayout.Italian",
                name: "Italian",
                localeCode: "IT"
            ),
            PhysicalKeyboardRecordID(rawValue: "desk"): EligibleInputSource(
                identifier: "com.apple.keylayout.US",
                name: "U.S.",
                localeCode: "US"
            )
        ]
    )
    let travel = try #require(list.rows.first { $0.id == "k2" })
    let desk = try #require(list.rows.first { $0.id == "desk" })

    #expect(travel.physicalKeyboardName == "Travel")
    #expect(travel.subtitle == "Keychron K2 - Connected")
    #expect(travel.assignedInputSourceName == "Italian")
    #expect(travel.assignedLocaleCode == "IT")

    // The name line already carries the product name without a Custom name.
    #expect(desk.physicalKeyboardName == "HHKB Professional")
    #expect(desk.subtitle == "Connected")
    #expect(desk.assignedLocaleCode == "US")
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
        assignedInputSources: panelNames("travel", "Italian")
    )
    let row = try #require(list.rows.first)

    #expect(list.rows.count == 1)
    #expect(row.physicalKeyboardName == "Travel")
    #expect(row.assignedInputSourceName == "Italian")
}

@Test("Menu-bar assignment order stays stable when the active keyboard changes")
func menuBarAssignmentListOrderIgnoresActiveKeyboard() {
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
        assignedInputSources: panelNames(
            "active", "Later",
            "apple", "US",
            "zebra", "Italian",
            "desk", "French",
            "zeta", "German"
        )
    )

    #expect(list.rows.map(\.physicalKeyboardName) == [
        "Apple",
        "Later Active",
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
        assignedInputSources: panelNames(
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
        assignedInputSources: [:]
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
        assignedInputSources: panelNames("ready", "Italian")
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
        assignedInputSources: [:]
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
        assignedInputSources: Dictionary(
            uniqueKeysWithValues: (1...5).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), panelInputSource("US"))
            }
        )
    )
    let six = MenuBarAssignmentList(
        physicalKeyboards: (1...6).map { index in
            makeAssignedPanelKeyboard(name: "Board \(index)", identifier: "board-\(index)")
        },
        assignedInputSources: Dictionary(
            uniqueKeysWithValues: (1...6).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), panelInputSource("US"))
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
        assignedInputSources: Dictionary(
            uniqueKeysWithValues: (1...count).map { index in
                (PhysicalKeyboardRecordID(rawValue: "board-\(index)"), panelInputSource("US"))
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
    #expect(content.footer.about.title == "About Keyameleon")
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
    #expect(content.footer.about.id == .about)
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

@Test("Permission notice prefers Open System Settings and closes the panel")
@MainActor
func menuBarPanelPermissionNoticeKeepsRecoveryActionOutOfFooter() throws {
    let content = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )
    let action = try #require(content.notice?.action)

    #expect(content.notice?.title == "Input Monitoring required")
    #expect(content.notice?.detail == "Keyameleon can't detect keyboard activity until you allow access in System Settings.")
    #expect(content.notice?.tone == .warning)
    #expect(action.id == .openSystemSettings)
    #expect(action.title == "Open System Settings")
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
    #expect(content.actionTitles.contains("Open System Settings") == false)
}

@Test("Permission notice falls back to Request Permission without a Settings action")
@MainActor
func menuBarPanelPermissionNoticeFallsBackToRequest() throws {
    let content = makeMenuBarPanelContent(
        outcome: .permissionRequiredFixture(availableActions: [.pause, .requestPermission])
    )
    let action = try #require(content.notice?.action)

    #expect(action.id == .requestPermission)
    #expect(action.title == "Request Permission")
}

@Test("Native menu shortcuts map to Command-P, Command-comma, and Command-Q")
func menuBarPanelCommandShortcutMapping() {
    for id in [MenuBarPanelActionID.pause, .resume] {
        #expect(id.shortcut?.rawValue == "p")
    }
    #expect(MenuBarPanelActionID.settings.shortcut?.rawValue == ",")
    #expect(MenuBarPanelActionID.quit.shortcut?.rawValue == "q")
    for id in [MenuBarPanelActionID.about, .requestPermission, .openSystemSettings,
               .checkAgain, .retryNow, .retryPersistence, .continueSetup, .checkForUpdates] {
        #expect(id.shortcut == nil)
    }
}

@Test("Assignment subtitles describe built-in, active, and disconnected keyboard states")
func menuBarPanelAssignmentSubtitlesDescribeState() throws {
    let builtIn = PhysicalKeyboard(
        id: .builtIn,
        productName: "MacBook Keyboard",
        customName: nil,
        transport: .usb,
        isBuiltIn: true,
        assignmentState: .assigned(try #require(KeyboardAssignment(inputSourceIdentifier: "com.example.us"))),
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            builtIn,
            makeAssignedPanelKeyboard(name: "Keychron K2", identifier: "office", isActive: true,
                                      customName: "Office Keyboard"),
            makeAssignedPanelKeyboard(name: "HHKB Professional", identifier: "travel",
                                      connectionState: .disconnected, customName: "Travel Keyboard")
        ],
        assignedInputSources: [:]
    )
    #expect(list.rows.map(\.subtitle) == [
        "Built-in", "Keychron K2 - Active", "HHKB Professional - Disconnected"
    ])
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
    #expect(makeMenuBarPanelContent(outcome: .readyFixture(), isSetupComplete: false).notice?.tone == .neutral)
}

@Test("Permission Required notice has no action when unavailable")
@MainActor
func menuBarPanelPermissionNoticeOmitsUnavailableRequestAction() {
    let outcome = ActivityTriggeredSwitchingOutcome.permissionRequiredFixture(
        availableActions: [.pause]
    )

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.action == nil)
}

@Test("Temporarily Unavailable explains sleeping and keeps Pause in footer")
@MainActor
func menuBarPanelTemporarilyUnavailableNoticeExplainsSleeping() {
    let content = makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture())

    #expect(content.notice?.detail == "The Mac is sleeping. Activity-Triggered Switching resumes automatically.")
    #expect(content.notice?.action == nil)
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

    #expect(content.notice?.detail == "The Mac is sleeping. Activity-Triggered Switching resumes automatically.")
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

        #expect(content.notice?.detail == "\(reason) Activity-Triggered Switching resumes automatically.")
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

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Activity-Triggered Switching resumes automatically.")
}

@Test("Paused panel marks the title and shows no notice")
@MainActor
func menuBarPanelPausedMarksTitleWithoutNotice() {
    let content = makeMenuBarPanelContent(outcome: .pausedFixture())

    #expect(content.pausedMarker == "(Paused)")
    #expect(content.notice == nil)
    #expect(overflow(content, .resume)?.title == "Resume Switching")
}

@Test("Paused marker appears only while switching is paused")
@MainActor
func menuBarPanelPausedMarkerAppearsOnlyWhilePaused() {
    #expect(makeMenuBarPanelContent(outcome: .readyFixture()).pausedMarker == nil)
    #expect(makeMenuBarPanelContent(outcome: .temporarilyUnavailableFixture()).pausedMarker == nil)
    #expect(makeMenuBarPanelContent(outcome: .permissionRequiredFixture()).pausedMarker == nil)
    #expect(makeMenuBarPanelContent(outcome: .pausedFixture()).pausedMarker == "(Paused)")
}

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

    #expect(notice?.title == "Input Source differs")
    #expect(notice?.detail == "The current Input Source is Italian. Travel's Keyboard Assignment is U.S.")
    #expect(notice?.action == nil)
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

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "The current Input Source is Italian. The Keyboard Assignment is U.S.")
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

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "The current Input Source is U.S. Travel's Keyboard Assignment is Italian.")
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

    #expect(content.notice?.title == "Couldn't select the Keyboard Assignment")
    #expect(content.notice?.detail == "Retry the Keyboard Assignment for Travel.")
    #expect(action.id == .retryNow)
    #expect(action.title == "Retry Now")
    #expect(overflowIDs(content) == [.pause, .settings, .checkForUpdates, .quit])
}

@Test("Selection-failure notice stays without Retry Now when action is unavailable")
@MainActor
func menuBarPanelSelectionFailureNoticeOmitsUnavailableRetryAction() {
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

    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.detail == "Retry the Keyboard Assignment.")
    #expect(makeMenuBarPanelContent(outcome: outcome).notice?.action == nil)
}

@Test("Keyboard Assignment needed notice names one unassigned Physical Keyboard")
@MainActor
func menuBarPanelUnassignedNoticeUsesKeyboardName() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.title == "Keyboard Assignment needed")
    #expect(content.notice?.detail == "Travel has no Keyboard Assignment.")
    #expect(content.notice?.action == nil)
}

@Test("Keyboard Assignment needed notice preserves Physical Keyboard order")
@MainActor
func menuBarPanelUnassignedNoticePreservesKeyboardOrder() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned),
            makePanelKeyboard(name: "Desk", identifier: "desk", assignmentState: .unassigned)
        ]
    )

    #expect(content.notice?.detail == "Travel and Desk have no Keyboard Assignment.")
}

@Test("Keyboard Assignment needed notice counts three unassigned Physical Keyboards")
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

    #expect(content.notice?.detail == "3 Physical Keyboards have no Keyboard Assignment.")
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

    #expect(content.notice?.title == "Couldn't select the Keyboard Assignment")
}

@Test("Input Source mismatch notice outranks unassigned and unfinished setup")
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
        ],
        isSetupComplete: false
    )

    #expect(content.notice?.title == "Input Source differs")
}

@Test("Unassigned notice outranks unfinished Guided setup")
@MainActor
func menuBarPanelNoticePrioritizesUnassignedKeyboardOverSetup() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [
            makePanelKeyboard(name: "Travel", identifier: "travel", assignmentState: .unassigned)
        ],
        isSetupComplete: false
    )

    #expect(content.notice?.title == "Keyboard Assignment needed")
}

@Test("Unfinished Guided setup notice appears when no earlier condition matches")
@MainActor
func menuBarPanelNoticeExplainsUnfinishedGuidedSetup() {
    let content = makeMenuBarPanelContent(
        outcome: .readyFixture(),
        isSetupComplete: false
    )

    #expect(content.notice?.title == "Guided setup is not finished")
    #expect(content.notice?.detail == "Continue Guided Setup to finish.")
}

private func makeMenuBarPanelContent(
    outcome: ActivityTriggeredSwitchingOutcome,
    physicalKeyboards: [PhysicalKeyboard] = [],
    assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource] = [:],
    marketingVersion: String? = "0.1.0",
    isSetupComplete: Bool = true,
    canCheckForUpdates: Bool = false
) -> MenuBarPanelContent {
    MenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: physicalKeyboards,
        assignedInputSources: assignedInputSources,
        marketingVersion: marketingVersion,
        isSetupComplete: isSetupComplete,
        canCheckForUpdates: canCheckForUpdates
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

private func overflow(
    _ content: MenuBarPanelContent,
    _ id: MenuBarPanelActionID
) -> MenuBarPanelContent.Action? {
    content.footer.actions.first { $0.id == id }
}

private func overflowIDs(_ content: MenuBarPanelContent) -> [MenuBarPanelActionID] {
    content.footer.actions.map(\.id)
}

private func panelInputSource(_ name: String) -> EligibleInputSource {
    EligibleInputSource(identifier: "com.example.\(name)", name: name)
}

private func panelNames(_ pairs: String...) -> [PhysicalKeyboardRecordID: EligibleInputSource] {
    Dictionary(
        uniqueKeysWithValues: stride(from: 0, to: pairs.count, by: 2).map { index in
            (PhysicalKeyboardRecordID(rawValue: pairs[index]), panelInputSource(pairs[index + 1]))
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
