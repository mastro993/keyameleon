import SwiftUI

/// Keyboard Assignments block. Actions stay outside this view so they remain fixed.
struct MenuBarAssignmentSection: View {
    let list: MenuBarAssignmentList
    @ScaledMetric(relativeTo: .body) private var assignmentRowHeight = 52

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
        let rows = VStack(alignment: .leading, spacing: 8) {
            ForEach(list.rows) { row in
                MenuBarAssignmentRowView(row: row)
                    .frame(minHeight: rowHeight, alignment: .top)
            }
        }

        if list.scrolls {
            ScrollView {
                rows
            }
            .scrollIndicators(.automatic)
            .frame(height: Self.scrollerHeight(rowHeight: rowHeight))
        } else {
            rows
        }
    }

    private static func scrollerHeight(rowHeight: CGFloat) -> CGFloat {
        let visibleRows = CGFloat(MenuBarAssignmentList.visibleRowLimit)
        let spacing = 8 * (visibleRows - 1)
        return rowHeight * visibleRows + spacing
    }
}

struct MenuBarAssignmentRowView: View {
    let row: MenuBarAssignmentList.Row

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body)
                    .lineLimit(1)
                Text(row.assignedInputSourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.showsWarningSymbol {
                Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .opacity(row.isDimmed ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.physicalKeyboardName)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isStaticText)
        .allowsHitTesting(false)
    }

    private var symbolName: String {
        switch row.connectionMark {
        case .active:
            "dot.circle.fill"
        case .connected:
            "circle"
        case .disconnected:
            "circle.dotted"
        }
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
