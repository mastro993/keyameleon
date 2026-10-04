import Testing
@testable import Keyameleon

@Test("Onboarding subtitle prefixes the product only for a custom name")
func onboardingSubtitleUsesOriginalNameOnlyAfterRename() {
    let unrenamed = makeOnboardingRowKeyboard(id: "identity:magic", name: "Magic Keyboard")
    #expect(OnboardingPhysicalKeyboardRow(physicalKeyboard: unrenamed, exclusionKey: nil)
        .subtitle(connectedExcludedKeys: []) == "Connected")
    #expect(OnboardingPhysicalKeyboardRow(physicalKeyboard: unrenamed.asDisconnected(), exclusionKey: nil)
        .subtitle(connectedExcludedKeys: []) == "Disconnected")

    let renamed = PhysicalKeyboard(
        id: unrenamed.id, productName: "Magic Keyboard", customName: "Desk Keyboard",
        transport: .usb, isBuiltIn: false, assignmentState: .unassigned,
        connectedServiceCount: 0, connectionState: .disconnected, isActive: false
    )
    #expect(OnboardingPhysicalKeyboardRow(physicalKeyboard: renamed, exclusionKey: nil)
        .subtitle(connectedExcludedKeys: []) == "Magic Keyboard - Disconnected")

    let exclusion = SavedPhysicalKeyboardExclusion(key: "identity:magic", name: "Desk Keyboard")
    let saved = SavedPhysicalKeyboardRecord(
        identityKey: "identity:magic|anchor:serial:magic", productName: "Magic Keyboard",
        customName: "Desk Keyboard"
    )
    let hidden = OnboardingPhysicalKeyboardRow(exclusion: exclusion, savedRecord: .matched(saved))
    #expect(OnboardingPhysicalKeyboardRow(physicalKeyboard: unrenamed.applying(savedRecord: saved), exclusionKey: nil)
        .subtitle(connectedExcludedKeys: []) == "Magic Keyboard - Connected")
    #expect(hidden.subtitle(connectedExcludedKeys: [exclusion.key]) == "Magic Keyboard - Connected")
    #expect(hidden.subtitle(connectedExcludedKeys: []) == "Magic Keyboard - Disconnected")
    #expect(OnboardingPhysicalKeyboardRow(exclusion: exclusion, savedRecord: .missing)
        .subtitle(connectedExcludedKeys: [exclusion.key]) == "Connected")
    #expect(OnboardingPhysicalKeyboardRow(exclusion: exclusion, savedRecord: .ambiguous)
        .subtitle(connectedExcludedKeys: []) == "Disconnected")
    let blankName = SavedPhysicalKeyboardRecord(
        identityKey: saved.identityKey, productName: saved.productName, customName: "  "
    )
    #expect(OnboardingPhysicalKeyboardRow(exclusion: exclusion, savedRecord: .matched(blankName))
        .subtitle(connectedExcludedKeys: []) == "Disconnected")
    let sameName = SavedPhysicalKeyboardRecord(
        identityKey: saved.identityKey, productName: saved.productName, customName: saved.productName
    )
    #expect(OnboardingPhysicalKeyboardRow(exclusion: exclusion, savedRecord: .matched(sameName))
        .subtitle(connectedExcludedKeys: [exclusion.key]) == "Magic Keyboard - Connected")
}

@Test("Excluding and restoring preserves onboarding row identity and order")
@MainActor
func excludingAndRestoringPreservesOnboardingRowIdentityAndOrder() {
    let firstKeyboard = makeOnboardingRowKeyboard(
        id: "identity:first|anchor:serial:first",
        name: "First Keyboard"
    )
    let secondKeyboard = makeOnboardingRowKeyboard(
        id: "identity:second|anchor:serial:second",
        name: "Second Keyboard"
    )
    let firstKey = "identity:first"
    let secondKey = "identity:second"
    let exclusion = SavedPhysicalKeyboardExclusion(key: firstKey, name: "First Keyboard")
    var rows = OnboardingPhysicalKeyboardRows(
        physicalKeyboards: [firstKeyboard, secondKeyboard],
        exclusionKeyFor: { keyboardID in
            keyboardID == firstKeyboard.id ? firstKey : secondKey
        }
    )
    let originalIDs = rows.rows.map(\.id)

    rows.reconcile(
        physicalKeyboards: [secondKeyboard],
        exclusions: [exclusion],
        exclusionKeyFor: { $0 == secondKeyboard.id ? secondKey : firstKey }
    )

    #expect(rows.rows.map(\.id) == originalIDs)
    #expect(rows.rows[0].state == .excluded(exclusion, .missing))
    #expect(rows.rows[1].state == .included(secondKeyboard))

    rows.reconcile(
        physicalKeyboards: [firstKeyboard, secondKeyboard],
        exclusions: [],
        exclusionKeyFor: { $0 == firstKeyboard.id ? firstKey : secondKey }
    )

    #expect(rows.rows.map(\.id) == originalIDs)
    #expect(rows.rows[0].state == .included(firstKeyboard))
    #expect(rows.rows[1].state == .included(secondKeyboard))
}

@Test("Repeated exclusions keep shared hardware-key rows unique and in place")
@MainActor
func repeatedExclusionsKeepSharedHardwareKeyRowsUniqueAndInPlace() {
    let firstKeyboard = makeOnboardingRowKeyboard(id: "service:first", name: "Receiver")
    let secondKeyboard = makeOnboardingRowKeyboard(id: "service:second", name: "Receiver")
    let hardwareKey = "hardware:200:100:Model"
    let exclusion = SavedPhysicalKeyboardExclusion(key: hardwareKey, name: "Receiver")
    var rows = OnboardingPhysicalKeyboardRows(
        physicalKeyboards: [firstKeyboard, secondKeyboard],
        exclusionKeyFor: { _ in hardwareKey }
    )
    let originalIDs = rows.rows.map(\.id)

    for _ in 0..<2 {
        rows.reconcile(
            physicalKeyboards: [],
            exclusions: [exclusion],
            exclusionKeyFor: { _ in hardwareKey }
        )
    }

    #expect(rows.rows.map(\.id) == originalIDs)
    #expect(Set(rows.rows.map(\.id)).count == 2)
    #expect(rows.rows.map(\.state) == [.excluded(exclusion, .missing), .excluded(exclusion, .missing)])

    let newKeyboard = makeOnboardingRowKeyboard(id: "identity:new", name: "New Keyboard")
    rows.reconcile(
        physicalKeyboards: [newKeyboard],
        exclusions: [exclusion],
        exclusionKeyFor: { $0 == newKeyboard.id ? "identity:new" : hardwareKey }
    )

    #expect(rows.rows.map(\.id) == originalIDs + [.keyboard(newKeyboard.id)])
    #expect(rows.rows.last?.state == .included(newKeyboard))
}

@Test("Excluded row retains its saved assignment through reconciliation and reopening")
@MainActor
func excludedRowRetainsSavedAssignmentAfterReopening() throws {
    let keyboard = makeOnboardingRowKeyboard(
        id: "identity:travel|anchor:serial:travel",
        name: "Travel"
    )
    let exclusion = SavedPhysicalKeyboardExclusion(key: "identity:travel", name: "Travel")
    let saved = SavedPhysicalKeyboardRecord(
        identityKey: keyboard.id.rawValue,
        productName: "Keychron K2",
        customName: "Travel",
        keyboardAssignment: KeyboardAssignment(inputSourceIdentifier: "com.example.german")
    )
    var rows = OnboardingPhysicalKeyboardRows(
        physicalKeyboards: [keyboard],
        savedRecords: [saved],
        exclusionKeyFor: { _ in exclusion.key }
    )
    let originalID = try #require(rows.rows.first?.id)
    rows.reconcile(
        physicalKeyboards: [], exclusions: [exclusion], savedRecords: [saved],
        exclusionKeyFor: { _ in exclusion.key }
    )
    #expect(rows.rows.first?.id == originalID)
    #expect(rows.rows.first?.state == .excluded(exclusion, .matched(saved)))

    let reopened = OnboardingPhysicalKeyboardRows(
        exclusions: [exclusion], savedRecords: [saved], exclusionKeyFor: { _ in nil }
    )
    #expect(reopened.rows.first?.state == .excluded(exclusion, .matched(saved)))

    rows.reconcile(
        physicalKeyboards: [keyboard], exclusions: [], savedRecords: [saved],
        exclusionKeyFor: { _ in exclusion.key }
    )
    #expect(rows.rows.first?.id == originalID)
    #expect(rows.rows.first?.state == .included(keyboard))
}

@Test("Excluded group selects anchored record and marks fresh collisions ambiguous")
@MainActor
func excludedGroupDoesNotInventAnAssignmentForCollisions() throws {
    let keyboard = makeOnboardingRowKeyboard(id: "identity:shared|anchor:first", name: "First")
    let exclusion = SavedPhysicalKeyboardExclusion(key: "identity:shared", name: "Receiver")
    let first = SavedPhysicalKeyboardRecord(
        identityKey: keyboard.id.rawValue, productName: "First",
        keyboardAssignment: KeyboardAssignment(inputSourceIdentifier: "com.example.us")
    )
    let second = SavedPhysicalKeyboardRecord(
        identityKey: "identity:shared|anchor:second", productName: "Second",
        keyboardAssignment: KeyboardAssignment(inputSourceIdentifier: "com.example.german")
    )
    var rows = OnboardingPhysicalKeyboardRows(
        physicalKeyboards: [keyboard], exclusionKeyFor: { _ in exclusion.key }
    )
    rows.reconcile(
        physicalKeyboards: [], exclusions: [exclusion], savedRecords: [first, second],
        exclusionKeyFor: { _ in exclusion.key }
    )
    #expect(rows.rows.first?.state == .excluded(exclusion, .matched(first)))

    let reopened = OnboardingPhysicalKeyboardRows(
        exclusions: [exclusion], savedRecords: [first, second], exclusionKeyFor: { _ in nil }
    )
    #expect(reopened.rows.first?.state == .excluded(exclusion, .ambiguous))
}

@Test("Persisted exclusions appear on onboarding and unavailable devices disappear on restore")
@MainActor
func persistedExclusionsAppearAndUnavailableDevicesDisappearOnRestore() {
    let exclusion = SavedPhysicalKeyboardExclusion(
        key: "hardware:200:100:Model",
        name: "USB Receiver"
    )
    var rows = OnboardingPhysicalKeyboardRows(
        exclusions: [exclusion],
        exclusionKeyFor: { _ in nil }
    )

    #expect(rows.rows == [OnboardingPhysicalKeyboardRow(exclusion: exclusion)])

    rows.reconcile(physicalKeyboards: [], exclusions: [], exclusionKeyFor: { _ in nil })

    #expect(rows.rows.isEmpty)
}

private func makeOnboardingRowKeyboard(id: String, name: String) -> PhysicalKeyboard {
    PhysicalKeyboard(
        id: PhysicalKeyboardRecordID(rawValue: id),
        productName: name,
        customName: nil,
        transport: .usb,
        isBuiltIn: false,
        assignmentState: .unassigned,
        connectedServiceCount: 1,
        connectionState: .connected,
        isActive: false
    )
}
