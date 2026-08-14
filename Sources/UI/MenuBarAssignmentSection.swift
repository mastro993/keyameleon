import SwiftUI

/// Keyboards block. Actions stay outside this view so they remain fixed.
struct MenuBarAssignmentSection: View {
    let list: MenuBarAssignmentList
    @ScaledMetric(relativeTo: .body) private var assignmentRowHeight = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.heading)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            if let emptyMessage = list.emptyMessage {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MenuBarAssignmentRows(
                    list: list,
                    rowHeight: assignmentRowHeight
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MenuBarAssignmentRows: View {
    let list: MenuBarAssignmentList
    let rowHeight: CGFloat

    var body: some View {
        let stack = LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(list.rows) { row in
                MenuBarAssignmentPill(row: row)
                    .frame(minHeight: rowHeight, alignment: .top)
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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body.weight(row.isActive ? .semibold : .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(row.assignedInputSourceName)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.65))
                    .lineLimit(1)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                if row.isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.07), in: Capsule())
                        .accessibilityHidden(true)
                }

                if row.showsWarningSymbol {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.black.opacity(0.65))
                        .accessibilityHidden(true)
                }
            }
        }
        .modifier(
            MenuBarAssignmentPillStyle(
                isActive: row.isActive,
                isDimmed: row.isDimmed
            )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: row.isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.physicalKeyboardName)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isStaticText)
        .allowsHitTesting(false)
    }

    private var accessibilityValue: String {
        [
            row.accessibilityMark,
            row.assignedInputSourceName,
            row.warningNote
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

private struct MenuBarAssignmentPillStyle: ViewModifier {
    let isActive: Bool
    let isDimmed: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .opacity(isDimmed ? 0.5 : 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: shape)
            .overlay {
                if isActive {
                    shape.strokeBorder(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                }
            }
            .compositingGroup()
            .clipShape(shape)
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
