import SwiftUI

struct MenuBarAssignmentPill: View {
    let row: MenuBarAssignmentList.Row
    var emphasis: MenuBarAssignmentEmphasis = .standard

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Menu.rowGap) {
            MenuBarConnectionMark(mark: row.connectionMark)

            VStack(alignment: .leading, spacing: Theme.Menu.detailGap) {
                Text(row.physicalKeyboardName)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(row.isDimmed ? Theme.Menu.muted : Color.primary)
                    .lineLimit(MenuBarPanelLayout.nameLineLimit)
                Text(row.subtitle)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(row.isDimmed ? Theme.Menu.muted : Color.secondary)
                    .lineLimit(MenuBarPanelLayout.subtitleLineLimit)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(row.isDimmed ? Theme.Menu.muted : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.showsWarningSymbol {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(row.isDimmed ? Theme.Menu.muted : Color.secondary)
                    .accessibilityHidden(true)
            }

            if let localeCode = row.assignedLocaleCode {
                Text(localeCode)
                    .font(Theme.Typography.chip)
                    .foregroundStyle(row.isDimmed ? Theme.Menu.muted : Color.primary)
                    .lineLimit(1)
                    .frame(minWidth: Theme.Menu.badgeWidth, minHeight: Theme.Menu.badgeHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                            .strokeBorder(
                                emphasis == .highContrast ? Theme.Menu.strongBadgeBorder : Theme.Menu.badgeBorder,
                                lineWidth: 1
                            )
                    }
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
}

private struct MenuBarConnectionMark: View {
    let mark: MenuBarAssignmentList.ConnectionMark

    var icon: String {
        switch mark {
        case .active: "circle.fill"
        case .connected: "circle"
        case .disconnected: "circle.dashed"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(mark == .active ? Theme.Menu.accent
                : mark == .connected ? Color.primary : Theme.Menu.muted)
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
#Preview("Assignment pill disconnected") {
    MenuBarAssignmentPill(
        row: MenuBarAssignmentList.Row(
            id: "preview-disconnected",
            physicalKeyboardName: "Office Keyboard",
            subtitle: "HHKB Professional - Disconnected",
            assignedInputSourceName: "German",
            assignedLocaleCode: "DE",
            connectionMark: .disconnected,
            isDimmed: true,
            warningNote: nil,
            showsWarningSymbol: false
        )
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .padding()
    .preferredColorScheme(.dark)
}
#endif
