import SwiftUI

struct MenuBarAssignmentPill: View {
    let row: MenuBarAssignmentList.Row
    var emphasis: MenuBarAssignmentEmphasis = .standard

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Menu.rowGap) {
            MenuBarConnectionMark(mark: row.connectionMark)
                .opacity(contentOpacity)

            Text(row.physicalKeyboardName)
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(.primary)
                .lineLimit(MenuBarPanelLayout.nameLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(contentOpacity)

            if row.showsWarningSymbol {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if let localeCode = row.assignedLocaleCode {
                Text(localeCode)
                    .font(Theme.Typography.chip)
                    .foregroundStyle(.background)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, Theme.Menu.badgeInset)
                    .frame(minWidth: Theme.Menu.badgeWidth, minHeight: Theme.Menu.badgeHeight)
                    .background(
                        Color.primary.opacity(contentOpacity),
                        in: .rect(cornerRadius: Theme.Menu.badgeRadius)
                    )
                    .accessibilityHidden(true)
            }
        }
        .modifier(
            MenuBarAssignmentPillStyle(
                connectionMark: row.connectionMark,
                emphasis: emphasis
            )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: row.connectionMark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
        .accessibilityAddTraits(.isStaticText)
        .allowsHitTesting(false)
    }

    private var contentOpacity: Double {
        guard row.isDimmed else { return 1 }
        return emphasis == .highContrast
            ? Theme.Menu.highContrastDisconnectedOpacity
            : Theme.Menu.disconnectedOpacity
    }
}

private struct MenuBarConnectionMark: View {
    let mark: MenuBarAssignmentList.ConnectionMark

    var icon: String {
        switch mark {
        case .active: "checkmark.circle.fill"
        case .connected: "circle"
        case .disconnected: "circle.dashed"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(mark == .active ? Theme.Menu.accent : Color.primary)
            .frame(width: Theme.Menu.statusSize, height: Theme.Menu.statusSize)
            .accessibilityHidden(true)
    }
}

private struct MenuBarAssignmentPillStyle: ViewModifier {
    let connectionMark: MenuBarAssignmentList.ConnectionMark
    let emphasis: MenuBarAssignmentEmphasis
    @ScaledMetric(relativeTo: .body) private var rowHeight = Theme.Menu.rowHeight

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Menu.rowRadius, style: .continuous)
        content
            .padding(.horizontal, Theme.Menu.rowInset)
            .padding(.vertical, Theme.Menu.sectionInset)
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .background(connectionMark == .active ? Theme.Menu.activeFill : .clear, in: shape)
            .overlay {
                if connectionMark == .active {
                    shape.strokeBorder(Theme.Menu.accent, lineWidth: emphasis == .highContrast ? 2 : 1)
                }
            }
    }
}

#if DEBUG
#Preview("Assignment pill active") {
    MenuBarAssignmentPill(
        row: MenuBarAssignmentList.Row(
            id: "preview-disconnected",
            physicalKeyboardName: "Office Keyboard",
            assignedInputSourceName: "German",
            assignedLocaleCode: "DE",
            connectionMark: .active,
            isDimmed: false,
            warningNote: nil
        )
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
    .preferredColorScheme(.dark)
}
#Preview("Assignment pill") {
    MenuBarAssignmentPill(
        row: MenuBarAssignmentList.Row(
            id: "preview-disconnected",
            physicalKeyboardName: "Office Keyboard",
            assignedInputSourceName: "German",
            assignedLocaleCode: "DE",
            connectionMark: .connected,
            isDimmed: false,
            warningNote: nil
        )
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
    .preferredColorScheme(.dark)
}
#Preview("Assignment pill disconnected") {
    MenuBarAssignmentPill(
        row: MenuBarAssignmentList.Row(
            id: "preview-disconnected",
            physicalKeyboardName: "Office Keyboard",
            assignedInputSourceName: "German",
            assignedLocaleCode: "DE",
            connectionMark: .disconnected,
            isDimmed: true,
            warningNote: nil
        )
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
    .preferredColorScheme(.dark)
}
#endif
