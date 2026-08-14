import SwiftUI

/// Keyboards block. Actions stay outside this view so they remain fixed.
struct MenuBarAssignmentSection: View {
    let list: MenuBarAssignmentList
    var emphasis: MenuBarAssignmentEmphasis = .rainbow
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding?
    @ScaledMetric(relativeTo: .body) private var assignmentRowHeight = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.heading)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

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
        .accessibilityElement(children: .contain)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                    .focusable(interactions: .activate)
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
        let spacing = 8 * (visibleRows - 1)
        return rowHeight * visibleRows + spacing
    }
}

struct MenuBarAssignmentPill: View {
    let row: MenuBarAssignmentList.Row
    var emphasis: MenuBarAssignmentEmphasis = .rainbow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body.weight(row.isActive ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(MenuBarPanelLayout.nameLineLimit)
                Text(row.assignedInputSourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(MenuBarPanelLayout.inputSourceLineLimit)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                if row.isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .accessibilityHidden(true)
                }

                if row.showsWarningSymbol {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .modifier(
            MenuBarAssignmentPillStyle(
                isActive: row.isActive,
                isDimmed: row.isDimmed,
                emphasis: emphasis
            )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: row.isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
        .accessibilityAddTraits(.isStaticText)
        .allowsHitTesting(false)
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

private struct MenuBarAssignmentPillStyle: ViewModifier {
    let isActive: Bool
    let isDimmed: Bool
    let emphasis: MenuBarAssignmentEmphasis

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .opacity(isDimmed ? 0.5 : 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay {
                if isActive {
                    activeBorder(in: shape)
                }
            }
            .compositingGroup()
            .clipShape(shape)
    }

    @ViewBuilder
    private func activeBorder(in shape: RoundedRectangle) -> some View {
        switch emphasis {
        case .rainbow:
            shape.strokeBorder(
                AngularGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                    center: .center
                ),
                lineWidth: 2
            )
        case .highContrastAccent:
            shape.strokeBorder(Color.accentColor, lineWidth: 2)
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
            assignedInputSourceNames: [
                PhysicalKeyboardRecordID(rawValue: "travel"): "Italian",
                PhysicalKeyboardRecordID(rawValue: "desk"): "US",
                PhysicalKeyboardRecordID(rawValue: "away"): "French"
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
                assignedInputSourceNames: [:]
            )
        )
        MenuBarAssignmentSection(
            list: MenuBarAssignmentList(
                physicalKeyboards: [],
                assignedInputSourceNames: [:]
            )
        )
    }
    .frame(width: 360)
    .padding()
}
#endif
