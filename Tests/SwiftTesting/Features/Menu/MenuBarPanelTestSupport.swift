import Foundation
@testable import Keyameleon

func makeMenuBarPanelContent(
    outcome: ActivityTriggeredSwitchingOutcome,
    physicalKeyboards: [PhysicalKeyboard] = [],
    assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource] = [:],
    marketingVersion: String? = "0.1.0",
    canCheckForUpdates: Bool = false
) -> MenuBarPanelContent {
    MenuBarPanelContent(
        outcome: outcome,
        physicalKeyboards: physicalKeyboards,
        assignedInputSources: assignedInputSources,
        marketingVersion: marketingVersion,
        canCheckForUpdates: canCheckForUpdates
    )
}

extension ActivityTriggeredSwitchingOutcome {
    static func readyFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .ready,
            availableActions: [.pause]
        )
    }

    static func pausedFixture() -> ActivityTriggeredSwitchingOutcome {
        fixture(switchingStatus: .paused, availableActions: [.resume])
    }

    static func permissionRequiredFixture(
        availableActions: Set<ActivityTriggeredSwitchingAction> = [.pause, .requestPermission]
    ) -> ActivityTriggeredSwitchingOutcome {
        fixture(
            switchingStatus: .permissionRequired,
            availableActions: availableActions
        )
    }

    static func permissionDeniedFixture() -> ActivityTriggeredSwitchingOutcome {
        permissionRequiredFixture(availableActions: [.pause, .openSystemSettings, .relaunch])
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

func overflow(
    _ content: MenuBarPanelContent,
    _ id: MenuBarPanelActionID
) -> MenuBarPanelContent.Action? {
    content.footer.actions.first { $0.id == id }
}

func overflowIDs(_ content: MenuBarPanelContent) -> [MenuBarPanelActionID] {
    content.footer.actions.map(\.id)
}

func panelInputSource(_ name: String) -> EligibleInputSource {
    EligibleInputSource(identifier: "com.example.\(name)", name: name)
}

func panelNames(_ pairs: String...) -> [PhysicalKeyboardRecordID: EligibleInputSource] {
    Dictionary(
        uniqueKeysWithValues: stride(from: 0, to: pairs.count, by: 2).map { index in
            (PhysicalKeyboardRecordID(rawValue: pairs[index]), panelInputSource(pairs[index + 1]))
        }
    )
}

func makeAssignedPanelKeyboard(
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

func makePanelKeyboard(
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
