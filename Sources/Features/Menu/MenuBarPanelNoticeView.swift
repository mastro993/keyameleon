import SwiftUI

@MainActor
struct MenuBarPanelNoticeView: View {
    let notice: MenuBarPanelNotice
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if notice.tone == .warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                } else if notice.tone == .neutral {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }

                Text(notice.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }

            Text(notice.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if let action = notice.action {
                Button {
                    perform(action)
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.automatic)
                .focusable()
                .focused(focusedTarget, equals: .action(id: action.id))
                .accessibilityIdentifier("menu-bar-notice-\(action.id.rawValue)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.title)
        .accessibilityValue(notice.detail)
        .accessibilityIdentifier("menu-bar-notice")
    }

    private var background: Color {
        switch notice.tone {
        case .warning:
            Color.yellow.opacity(0.16)
        case .neutral:
            Color.primary.opacity(0.06)
        }
    }
}

#if DEBUG
#Preview("Menu-bar notice") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Permission Required",
            detail: "Keyameleon needs Input Monitoring to observe Activation Activity.",
            action: MenuBarPanelContent.Action(
                id: .requestPermission,
                title: "Request Permission",
                isEnabled: true,
                closesPanel: false
            ),
            tone: .warning
        ),
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}

#Preview("Menu-bar notice informational") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Keyboard Assignment needed",
            detail: "Travel has no Keyboard Assignment.",
            action: nil,
            tone: .neutral
        ),
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}
#endif
