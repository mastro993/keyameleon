import SwiftUI

/// Keyboard Assignments block. Actions stay outside this view so they remain fixed.
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let chrome = MenuBarAssignmentPillChrome(
            id: row.id,
            isActive: row.isActive,
            colorScheme: colorScheme
        )

        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body.weight(row.isActive ? .semibold : .medium))
                    .foregroundStyle(chrome.titleStyle)
                    .lineLimit(1)
                Text(row.assignedInputSourceName)
                    .font(.caption)
                    .foregroundStyle(chrome.secondaryStyle)
                    .lineLimit(1)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(.caption2)
                        .foregroundStyle(chrome.secondaryStyle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.showsWarningSymbol {
                Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(chrome.secondaryStyle)
                    .accessibilityHidden(true)
            }
        }
        .modifier(
            MenuBarAssignmentPillStyle(
                fill: chrome.fill,
                fillOverlay: chrome.fillOverlay,
                border: chrome.border,
                borderWidth: chrome.borderWidth,
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
    let fill: Color
    let fillOverlay: Color
    let border: Color
    let borderWidth: CGFloat
    let isDimmed: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: shape)
            .background(fillOverlay, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: borderWidth)
            }
            .compositingGroup()
            .clipShape(shape)
            .opacity(isDimmed ? 0.5 : 1)
    }
}

/// Stable per-identity fill. Active pills sit on an opaque plate plus a soft accent wash.
private struct MenuBarAssignmentPillChrome {
    let fill: Color
    let fillOverlay: Color
    let border: Color
    let borderWidth: CGFloat
    let titleStyle: Color
    let secondaryStyle: Color

    init(id: String, isActive: Bool, colorScheme: ColorScheme) {
        let distinctive = Color(
            hue: Self.hue(for: id),
            saturation: colorScheme == .dark ? 0.40 : 0.34,
            brightness: colorScheme == .dark ? 0.46 : 0.93
        )
        if isActive {
            fill = Color(nsColor: .controlBackgroundColor)
            fillOverlay = Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10)
            border = Color.accentColor
            borderWidth = 2
            titleStyle = .primary
            secondaryStyle = Color.primary.opacity(0.72)
        } else {
            fill = distinctive.opacity(colorScheme == .dark ? 0.88 : 0.72)
            fillOverlay = .clear
            border = distinctive.opacity(0.48)
            borderWidth = 1
            titleStyle = .primary
            secondaryStyle = .secondary
        }
    }

    private static func hue(for id: String) -> Double {
        var hash: UInt64 = 2_166_136_261
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 16_777_619
        }
        return Double(hash % 360) / 360
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
