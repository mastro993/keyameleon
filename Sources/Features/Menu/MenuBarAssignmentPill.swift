import SwiftUI

struct MenuBarAssignmentPill: View {
    let row: MenuBarAssignmentList.Row
    var emphasis: MenuBarAssignmentEmphasis = .standard

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            MenuBarConnectionMark(mark: row.connectionMark)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body.weight(row.isActive ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(MenuBarPanelLayout.nameLineLimit)
                Text(row.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(MenuBarPanelLayout.subtitleLineLimit)
                if let warningNote = row.warningNote {
                    Text(warningNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.showsWarningSymbol {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .ifLet(row.warningNote) { view, warningNote in
                        view.help(warningNote)
                    }
            }

            if let localeCode = row.assignedLocaleCode {
                Text(localeCode)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.vertical, 2)
                    .frame(width: 25)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                emphasis.outlineColor,
                                lineWidth: emphasis.outlineLineWidth + 0.5
                            )
                    }
                    .accessibilityHidden(true)
            }
        }
        .modifier(
            MenuBarAssignmentPillStyle(
                connectionMark: row.connectionMark,
                isDimmed: row.isDimmed,
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
        case .active:
            "checkmark.circle.fill"
        case .connected:
            "circle"
        case .disconnected:
            "circle.slash"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(mark == .active ? .green : .primary)
            .frame(width: 16, height: 22)
            .opacity(mark == .active ? 1 : 0.25)
            .accessibilityHidden(true)
    }
}

private extension MenuBarAssignmentEmphasis {
    /// Shared outline vocabulary for the pill and its locale badge.
    var outlineColor: Color {
        Color.primary.opacity(self == .highContrast ? 0.5 : 0.25)
    }

    var outlineLineWidth: CGFloat {
        self == .highContrast ? 1.5 : 0.5
    }
}

private struct MenuBarAssignmentPillStyle: ViewModifier {
    let connectionMark: MenuBarAssignmentList.ConnectionMark
    let isDimmed: Bool
    let emphasis: MenuBarAssignmentEmphasis

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .opacity(isDimmed ? 0.55 : 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(connectionMark == .active ? Color.primary.opacity(0.12) : .clear, in: shape)
            .overlay { border(in: shape) }
            .compositingGroup()
            .clipShape(shape)
    }

    @ViewBuilder
    private func border(in shape: RoundedRectangle) -> some View {
        switch connectionMark {
        case .active:
            if emphasis == .highContrast {
                shape.strokeBorder(Color.accentColor, lineWidth: 2)
            }
        case .connected:
            shape.strokeBorder(borderColor, lineWidth: borderLineWidth)
        case .disconnected:
            shape.strokeBorder(
                borderColor,
                style: StrokeStyle(lineWidth: borderLineWidth, dash: [4, 3])
            )
        }
    }

    private var borderLineWidth: CGFloat {
        emphasis.outlineLineWidth
    }

    private var borderColor: Color {
        emphasis.outlineColor
    }
}

#if DEBUG
#Preview("Assignment pill disconnected") {
    MenuBarAssignmentPill(
        row: MenuBarAssignmentList.Row(
            id: "preview-disconnected",
            physicalKeyboardName: "Office Keyboard",
            subtitle: "HHKB Professional - Bluetooth",
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
