import Foundation
import Testing
@testable import Keyameleon

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

@Test("Menu-bar panel content keeps Keyboards heading, empty copy, and actions")
@MainActor
func menuBarPanelContentKeepsStatusAndActions() throws {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [],
        assignedInputSourceNames: [:],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )
    let titles = content.titles
    let headingIndex = try #require(titles.firstIndex(of: "Keyboards"))
    let statusIndex = try #require(titles.firstIndex { $0.hasPrefix("Switching Status:") })

    #expect(titles.first == "Keyboards")
    #expect(titles.contains("No assigned keyboards"))
    #expect(titles.contains("Open Keyameleon Settings to assign keyboards."))
    #expect(headingIndex < statusIndex)
    #expect(titles.contains { $0.hasPrefix("Active Physical Keyboard:") } == false)
    #expect(content.assignmentList.rows.isEmpty)
    #expect(content.actionTitles.contains("Pause Activity-Triggered Switching"))
    #expect(content.actionTitles.contains("Request Permission") == false)
    #expect(content.actionTitles.contains("Open Keyameleon…"))
    #expect(content.actionTitles.contains("Open System Settings"))
    #expect(content.actionTitles.contains("Check Again"))
    #expect(content.actionTitles.contains("Settings…"))
    #expect(content.actionTitles.contains("Check for Updates…"))
    #expect(content.actionTitles.contains("Quit Keyameleon"))
}

@Test("Menu-bar panel assignment rows stay read-only")
@MainActor
func menuBarPanelAssignmentRowsStayReadOnly() throws {
    let keyboard = makeAssignedPanelKeyboard(name: "Travel", identifier: "travel")
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [keyboard],
        assignedInputSourceNames: [
            PhysicalKeyboardRecordID(rawValue: "travel"): "Italian"
        ],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )
    let row = try #require(content.assignmentList.rows.first)

    #expect(row.id == "travel")
    #expect(content.noticeItems.contains { $0.id.hasPrefix("assignment-") } == false)
    #expect(content.footerItems.contains { $0.id.hasPrefix("assignment-") } == false)
    #expect(content.footerItems.contains { item in
        if case .action(.openKeyameleon, enabled: true) = item.kind {
            return true
        }
        return false
    })
}

@Test("Menu-bar panel shows Request Permission when listen permission is required")
@MainActor
func menuBarPanelShowsRequestPermissionWhenListenPermissionIsRequired() {
    let content = MenuBarPanelContent(
        outcome: .permissionRequiredFixture(),
        physicalKeyboards: [],
        assignedInputSourceNames: [:],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: false
    )

    #expect(content.titles.contains("Switching Status: Permission Required"))
    #expect(content.actionTitles.contains("Request Permission"))
    #expect(content.actionTitles.contains("Open System Settings"))
    #expect(content.actionTitles.contains("Check Again"))
    #expect(content.actionTitles.contains("Pause Activity-Triggered Switching") == false)
}

@Test("Menu-bar panel shows Resume when Activity-Triggered Switching is paused")
@MainActor
func menuBarPanelShowsResumeWhenPaused() {
    let content = MenuBarPanelContent(
        outcome: .pausedFixture(),
        physicalKeyboards: [],
        assignedInputSourceNames: [:],
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
func menuBarPanelShowsDismissibleUncleanExitNoticeAndReviewAction() throws {
    let content = MenuBarPanelContent(
        outcome: .readyFixture(),
        physicalKeyboards: [],
        assignedInputSourceNames: [:],
        isSetupComplete: true,
        canCheckForUpdates: true,
        hasPendingUncleanExitNotice: true
    )

    let titles = content.titles
    let headingIndex = try #require(titles.firstIndex(of: "Keyboards"))
    let diagnosticsIndex = try #require(titles.firstIndex(of: "Keyameleon did not exit cleanly."))

    #expect(headingIndex < diagnosticsIndex)
    #expect(content.actionTitles.contains("Review Diagnostics…"))
    #expect(content.actionTitles.contains("Dismiss Diagnostics Notice"))
}

private extension ActivityTriggeredSwitchingOutcome {
    static func permissionRequiredFixture() -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: .permissionRequired,
            temporarilyUnavailableReasons: [],
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: [.requestPermission, .openSystemSettings, .checkAgain]
        )
    }

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
