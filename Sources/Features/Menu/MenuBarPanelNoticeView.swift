import SwiftUI

@MainActor
struct MenuBarPanelNoticeView: View {
    let notice: MenuBarPanelNotice
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notice.title)
                .font(.body.weight(.medium))
                .accessibilityHidden(true)

            Text(notice.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if let action = notice.action {
                Button(action.title) {
                    perform(action)
                }
                .buttonStyle(.bordered)
                .focusable()
                .focused(focusedTarget, equals: .action(id: action.id))
                .accessibilityIdentifier("menu-bar-notice-\(action.id.rawValue)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.title)
        .accessibilityValue(notice.detail)
        .accessibilityIdentifier("menu-bar-notice")
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
            )
        ),
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}
#endif
