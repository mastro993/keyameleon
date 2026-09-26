import Foundation
import Testing
@testable import Keyameleon

@Test("An assigned Physical Keyboard shows its Input Source locale code")
func assignedKeyboardShowsInputSourceLocaleCode() {
    let row = makeRow(
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.Italian")!),
        assignedInputSourceName: "Italian",
        assignedInputSourceLocaleCode: "IT",
        connectionState: .connected,
        isActive: true
    )

    #expect(row.inputSourceControl == .change(name: "Italian", localeCode: "IT"))
    #expect(row.inputSourceControl?.displayTitle == "IT")
    #expect(row.statusText == "Connected · USB")
    #expect(row.warningText == nil)
    #expect(row.guidanceText == nil)
    #expect(row.hasAssignment)
    #expect(row.accessibilityValue == "Active · Connected · USB · Italian")
}

@Test("A Keyboard Assignment whose Input Source is unavailable reports Unavailable")
func unavailableInputSourceReportsUnavailable() {
    let row = makeRow(
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.Gone")!),
        assignedInputSourceName: nil
    )

    #expect(row.inputSourceControl == .unavailable)
    #expect(row.inputSourceControl?.title == "Input Source Unavailable")
    #expect(row.inputSourceControl?.displayTitle == "--")
    #expect(row.inputSourceControl?.needsAttention == true)
    #expect(row.hasAssignment)
    #expect(row.accessibilityValue == "Connected · USB · Input Source Unavailable")
}

@Test("An unassigned Physical Keyboard offers an Input Source to assign")
func unassignedKeyboardOffersAssign() {
    let row = makeRow(assignmentState: .unassigned, assignedInputSourceName: nil)

    #expect(row.inputSourceControl == .assign)
    #expect(row.inputSourceControl?.title == "Assign Input Source…")
    #expect(row.inputSourceControl?.displayTitle == "--")
    #expect(row.hasAssignment == false)
    #expect(row.accessibilityValue == "Connected · USB · Assign Input Source…")
}

@Test("An unsupported Physical Keyboard keeps its connection state and names the reason", arguments: [
    (PhysicalKeyboardUnsupportedReason.missingIdentity, "Physical Keyboard Identity unavailable"),
    (.unstableIdentity, "Physical Keyboard Identity unstable"),
    (.sharedIdentity, "Physical Keyboard Identity shared"),
    (.ambiguousIdentity, "Physical Keyboard Identity ambiguous")
])
func unsupportedKeyboardKeepsConnectionStateAndNamesReason(
    reason: PhysicalKeyboardUnsupportedReason,
    expectedDetail: String
) {
    let row = makeRow(assignmentState: .unsupported(reason), assignedInputSourceName: nil)

    #expect(row.inputSourceControl == nil)
    #expect(row.statusText == "Connected · USB")
    #expect(row.warningText == "Unsupported — \(expectedDetail)")
    #expect(row.hasAssignment == false)
    #expect(row.canRename == false)
}

@Test("Manual Physical Keyboard Designation guidance appears only when it is offered")
func designationGuidanceAppearsOnlyWhenOffered() {
    let offered = KeyboardSettingsRow(
        physicalKeyboard: makePhysicalKeyboard(assignmentState: .unsupported(.ambiguousIdentity)),
        assignedInputSourceName: nil,
        canReplace: false,
        canForget: false,
        canExclude: true,
        canStartManualDesignation: true
    )
    let notOffered = makeRow(
        assignmentState: .unsupported(.ambiguousIdentity),
        assignedInputSourceName: nil
    )

    #expect(offered.guidanceText == "Save it after it leaves and returns.")
    #expect(notOffered.guidanceText == nil)
    #expect(
        offered.accessibilityValue
            == "Connected · USB · Unsupported — Physical Keyboard Identity ambiguous · "
            + "Save it after it leaves and returns."
    )
}

@Test("A disconnected Physical Keyboard keeps its Input Source control")
func disconnectedKeyboardKeepsControl() {
    let row = makeRow(
        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.US")!),
        assignedInputSourceName: "U.S.",
        connectionState: .disconnected
    )

    #expect(row.statusText == "Disconnected")
    #expect(row.inputSourceControl == .change(name: "U.S.", localeCode: nil))
}

@Test("A Physical Keyboard without identity cannot be renamed")
func keyboardWithoutIdentityCannotBeRenamed() {
    let row = KeyboardSettingsRow(
        physicalKeyboard: makePhysicalKeyboard(
            id: "service:preview-unsupported",
            assignmentState: .unassigned
        ),
        assignedInputSourceName: nil,
        canReplace: false,
        canForget: false,
        canExclude: true,
        canStartManualDesignation: false
    )

    #expect(row.canRename == false)
    #expect(row.canExclude)
    #expect(row.hasActions)
}

@Test("A row with nothing to offer hides its actions menu")
func rowWithoutActionsHidesMenu() {
    let row = KeyboardSettingsRow(
        physicalKeyboard: makePhysicalKeyboard(
            id: "service:preview-unnamed",
            assignmentState: .unassigned
        ),
        assignedInputSourceName: nil,
        canReplace: false,
        canForget: false,
        canExclude: false,
        canStartManualDesignation: false
    )

    #expect(row.hasActions == false)
}

@Test("A built-in Physical Keyboard reports its transport as Built-in")
func builtInKeyboardReportsBuiltInTransport() {
    let row = KeyboardSettingsRow(
        physicalKeyboard: makePhysicalKeyboard(
            id: PhysicalKeyboardRecordID.builtIn.rawValue,
            transport: .bluetooth,
            isBuiltIn: true,
            assignmentState: .unassigned
        ),
        assignedInputSourceName: nil,
        canReplace: false,
        canForget: false,
        canExclude: false,
        canStartManualDesignation: false
    )

    #expect(row.statusText == "Connected · Built-in")
}

private func makeRow(
    assignmentState: PhysicalKeyboardAssignmentState,
    assignedInputSourceName: String?,
    assignedInputSourceLocaleCode: String? = nil,
    connectionState: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false
) -> KeyboardSettingsRow {
    KeyboardSettingsRow(
        physicalKeyboard: makePhysicalKeyboard(
            assignmentState: assignmentState,
            connectionState: connectionState,
            isActive: isActive
        ),
        assignedInputSourceName: assignedInputSourceName,
        assignedInputSourceLocaleCode: assignedInputSourceLocaleCode,
        canReplace: false,
        canForget: false,
        canExclude: false,
        canStartManualDesignation: false
    )
}

private func makePhysicalKeyboard(
    id: String = "identity:preview.keyboard|anchor:serial:preview-keyboard",
    transport: PhysicalKeyboardTransport = .usb,
    isBuiltIn: Bool = false,
    assignmentState: PhysicalKeyboardAssignmentState,
    connectionState: PhysicalKeyboardConnectionState = .connected,
    isActive: Bool = false
) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: id),
        productName: "Keychron K2",
        customName: nil,
        transport: transport,
        isBuiltIn: isBuiltIn,
        assignmentState: assignmentState,
        connectedServiceCount: connectionState == .connected ? 1 : 0,
        connectionState: connectionState,
        isActive: isActive
    )
}
