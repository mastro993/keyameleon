import AppKit
import Foundation
import Testing
import SwiftUI
@testable import Keyameleon

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
    #expect(travel.connectionMark == .connected)
    #expect(travel.assignedInputSourceName == "Italian")
    #expect(travel.assignedLocaleCode == "IT")

    // The name line already carries the product name without a Custom name.
    #expect(desk.physicalKeyboardName == "HHKB Professional")
    #expect(desk.connectionMark == .connected)
    #expect(desk.assignedLocaleCode == "US")
}

@Test("Menu follows Active Physical Keyboard when its assigned Input Source is already selected")
@MainActor
func menuBarPanelActivatesKeyboardWithCurrentInputSource() throws {
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "us")
    let source = EligibleInputSource(identifier: "us", name: "U.S.", localeCode: "US")
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [source]),
        inputSourceSelector: selector
    )
    startAndCheck(model)
    defer { model.activityTriggeredSwitching.stop() }
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 901)))
    let firstID = try #require(model.physicalKeyboards.first?.id)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(
        serviceID: 902, identity: "macos.keyboard.second", serialNumber: "keyboard-b"
    )))
    let secondID = try #require(model.physicalKeyboards.first { $0.id != firstID }?.id)
    for keyboard in model.physicalKeyboards {
        model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: source.identifier)
    }
    #expect(model.activePhysicalKeyboardID == nil)
    #expect(selector.currentInputSourceIdentifier() == source.identifier)

    let discovery = model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery
    let activities: [(serviceID: UInt64, keyboardID: PhysicalKeyboardRecordID)] = [
        (901, firstID), (902, secondID), (901, firstID)
    ]
    var selectionsAfterFirstActivity = 0
    for (index, activity) in activities.enumerated() {
        discovery.handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(serviceID: activity.serviceID, kind: .press)
        )
        if index == 0 {
            selectionsAfterFirstActivity = selector.selectCount
        }
        let content = MenuBarPanelContent(
            outcome: model.activityTriggeredSwitching.outcome,
            physicalKeyboards: model.physicalKeyboards,
            assignedInputSources: [firstID: source, secondID: source],
            marketingVersion: nil,
            canCheckForUpdates: false
        )
        #expect(model.activePhysicalKeyboardID == activity.keyboardID)
        #expect(content.assignmentList.rows.filter(\.isActive).map(\.id) == [activity.keyboardID.rawValue])
        #expect(selector.currentInputSourceIdentifier() == source.identifier)
        #expect(selector.selectCount == selectionsAfterFirstActivity)
    }
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
    #expect(row.assignedInputSourceName == "Input source unavailable")
    #expect(row.showsWarningSymbol)
    #expect(row.warningNote == "Choose another in Settings")
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
    #expect(broken.warningNote == "Choose another in Settings")
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
    #expect(list.emptyDescription == "Assign keyboards in Settings.")
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

@Test("Assignment rows show one title line and their connection state")
func menuBarPanelAssignmentRowsShowSingleTitleAndState() throws {
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
            makeAssignedPanelKeyboard(name: "Keychron K2", identifier: "office", isActive: true,
                                      customName: "Office Keyboard"),
            makeAssignedPanelKeyboard(name: "HHKB Professional", identifier: "travel",
                                      connectionState: .disconnected, customName: "Travel Keyboard"),
            builtIn
        ],
        assignedInputSources: [:]
    )
    #expect(list.rows.map(\.physicalKeyboardName) == [
        "MacBook Keyboard", "Office Keyboard", "Travel Keyboard"
    ])
    #expect(list.rows.map(\.connectionMark) == [.connected, .active, .disconnected])
    #expect(list.rows.map(\.isDimmed) == [false, false, true])
}

@Test("The Frontmost App's App Assignment comes first and takes the accent from the active keyboard")
@MainActor
func menuListShowsFrontmostAppAssignmentFirst() {
    let list = MenuBarAssignmentList(
        physicalKeyboards: [
            makeAssignedPanelKeyboard(name: "Active Board", identifier: "active", isActive: true)
        ],
        assignedInputSources: panelNames("active", "Italian"),
        frontmostAppAssignment: ActivityTriggeredSwitchingAppAssignment(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            inputSource: EligibleInputSource(identifier: "com.example.us", name: "U.S.", localeCode: "US")
        )
    )

    #expect(list.rows.map(\.physicalKeyboardName) == ["Terminal", "Active Board"])
    #expect(list.rows.map(\.isActive) == [true, false])
    #expect(list.rows.first?.appBundleIdentifier == "com.apple.Terminal")
    #expect(list.rows.first?.assignedLocaleCode == "US")
}
