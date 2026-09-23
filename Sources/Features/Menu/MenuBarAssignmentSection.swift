import SwiftUI

/// Keyboards block. Actions stay outside this view so they remain fixed.
struct MenuBarAssignmentSection: View {
    let list: MenuBarAssignmentList
    var emphasis: MenuBarAssignmentEmphasis = .standard
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding?
    @ScaledMetric(relativeTo: .body) private var assignmentRowHeight = 46

    var body: some View {
        if let emptyTitle = list.emptyTitle,
           let emptyDescription = list.emptyDescription {
            MenuBarAssignmentEmptyState(
                title: emptyTitle,
                description: emptyDescription
            )
        } else {
            MenuBarAssignmentRows(
                list: list,
                rowHeight: assignmentRowHeight,
                emphasis: emphasis,
                focusedTarget: focusedTarget
            )
        }
    }
}

private struct MenuBarAssignmentEmptyState: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "keyboard")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.07), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(description)
    }
}

private struct MenuBarAssignmentRows: View {
    let list: MenuBarAssignmentList
    let rowHeight: CGFloat
    let emphasis: MenuBarAssignmentEmphasis
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding?

    var body: some View {
        let stack = LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(list.rows) { row in
                MenuBarAssignmentPill(row: row, emphasis: emphasis)
                    .frame(minHeight: rowHeight, alignment: .top)
                    .focusable()
                    .modifier(MenuBarAssignmentFocusBinding(
                        target: .assignment(id: row.id),
                        focusedTarget: focusedTarget
                    ))
            }
        }

        if list.scrolls {
            ScrollView {
                stack
            }
            .scrollIndicators(.automatic)
            .frame(height: Self.scrollerHeight(rowHeight: rowHeight))
        } else {
            stack
        }
    }

    private static func scrollerHeight(rowHeight: CGFloat) -> CGFloat {
        let visibleRows = CGFloat(MenuBarAssignmentList.visibleRowLimit)
        let spacing = 4 * (visibleRows - 1)
        return rowHeight * visibleRows + spacing
    }
}

private struct MenuBarAssignmentFocusBinding: ViewModifier {
    let target: MenuBarPanelAccessibility.FocusTarget
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding?

    func body(content: Content) -> some View {
        if let focusedTarget {
            content.focused(focusedTarget, equals: target)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Assigned pills") {
    MenuBarAssignmentSection(
        list: MenuBarAssignmentList(
            physicalKeyboards: [
                PhysicalKeyboard(
                    id: PhysicalKeyboardRecordID(rawValue: "travel"),
                    productName: "Keychron K2",
                    customName: "Travel",
                    transport: .bluetooth,
                    isBuiltIn: false,
                    assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "it")!),
                    connectedServiceCount: 1,
                    connectionState: .connected,
                    isActive: true
                ),
                PhysicalKeyboard(
                    id: PhysicalKeyboardRecordID(rawValue: "desk"),
                    productName: "HHKB Professional",
                    customName: nil,
                    transport: .usb,
                    isBuiltIn: false,
                    assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "us")!),
                    connectedServiceCount: 1,
                    connectionState: .connected,
                    isActive: false
                ),
                PhysicalKeyboard(
                    id: PhysicalKeyboardRecordID(rawValue: "away"),
                    productName: "Realforce",
                    customName: "Studio",
                    transport: .usb,
                    isBuiltIn: false,
                    assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "fr")!),
                    connectedServiceCount: 0,
                    connectionState: .disconnected,
                    isActive: false
                )
            ],
            assignedInputSources: [
                PhysicalKeyboardRecordID(rawValue: "travel"): EligibleInputSource(
                    identifier: "com.apple.keylayout.Italian",
                    name: "Italian",
                    languageCode: "IT"
                ),
                PhysicalKeyboardRecordID(rawValue: "desk"): EligibleInputSource(
                    identifier: "com.apple.keylayout.US",
                    name: "U.S.",
                    languageCode: "EN"
                ),
                PhysicalKeyboardRecordID(rawValue: "away"): EligibleInputSource(
                    identifier: "com.apple.keylayout.French",
                    name: "French",
                    languageCode: "FR"
                )
            ]
        )
    )
    .frame(width: 360)
    .padding()
}

#Preview("Unavailable + empty") {
    VStack(spacing: 24) {
        MenuBarAssignmentSection(
            list: MenuBarAssignmentList(
                physicalKeyboards: [
                    PhysicalKeyboard(
                        id: PhysicalKeyboardRecordID(rawValue: "broken"),
                        productName: "Voyager",
                        customName: nil,
                        transport: .usb,
                        isBuiltIn: false,
                        assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "missing")!),
                        connectedServiceCount: 1,
                        connectionState: .connected,
                        isActive: false
                    )
                ],
                assignedInputSources: [:]
            )
        )
        MenuBarAssignmentSection(
            list: MenuBarAssignmentList(
                physicalKeyboards: [],
                assignedInputSources: [:]
            )
        )
    }
    .frame(width: 360)
    .padding()
}

#Preview("Assignment section empty") {
    MenuBarAssignmentSection(
        list: MenuBarAssignmentList(
            physicalKeyboards: [],
            assignedInputSources: [:]
        )
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
}

#Preview("Assignment section unavailable") {
    MenuBarAssignmentSection(
        list: MenuBarAssignmentList(
            physicalKeyboards: [
                KeyameleonPreviewFixtures.physicalKeyboard(
                    name: "Travel Keyboard",
                    assignment: "com.apple.keylayout.Missing"
                )
            ],
            assignedInputSources: [:]
        ),
        emphasis: .highContrast
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
}
#endif
