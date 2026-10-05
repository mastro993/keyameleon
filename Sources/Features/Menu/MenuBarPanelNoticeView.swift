import SwiftUI

@MainActor
struct MenuBarPanelNoticeView: View {
    let notice: MenuBarPanelNotice
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Menu.noticeGap) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Menu.noticeGap) {
                if notice.tone == .warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Menu.warning)
                        .accessibilityHidden(true)
                } else if notice.tone == .neutral {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Text(notice.title)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }

            Text(notice.detail)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if let action = notice.action {
                let button = Button {
                    perform(action)
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity)
                }
                .focusable()
                .focused(focusedTarget, equals: .action(id: action.id))
                .accessibilityIdentifier("menu-bar-notice-\(action.id.rawValue)")

                switch notice.tone {
                case .warning:
                    button.buttonStyle(.automatic)
                case .neutral:
                    button
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Menu.accent)
                }
            }
        }
        .padding(Theme.Menu.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: .rect(cornerRadius: Theme.Menu.rowRadius))
        .padding(.horizontal, Theme.Menu.innerInset)
        .padding(.top, Theme.Menu.noticeTopInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.title)
        .accessibilityValue(notice.detail)
        .accessibilityIdentifier("menu-bar-notice")
    }

    private var background: Color {
        switch notice.tone {
        case .warning:
            Theme.Menu.warningFill
        case .neutral:
            Theme.Menu.neutralFill
        }
    }
}

#if DEBUG
#Preview("Menu-bar notice") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Input Monitoring required",
            detail: "Keyameleon can't detect keyboard activity until you allow access in System Settings.",
            action: MenuBarPanelContent.Action(
                id: .openSystemSettings,
                title: "Open System Settings",
                isEnabled: true,
                closesPanel: true
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
