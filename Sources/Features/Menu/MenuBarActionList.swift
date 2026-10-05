import SwiftUI

/// Full-width tray actions styled like compact native menu rows.
struct MenuBarActionList: View {
    let actions: [MenuBarPanelContent.Action]
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(actions) { action in
                if action.id == .quit {
                    Divider()
                        .opacity(Theme.Menu.separatorOpacity)
                        .padding(.horizontal, -Theme.Menu.innerInset)
                        .padding(.vertical, Theme.Menu.quitSectionInset)
                }

                MenuBarActionRow(action: action) {
                    perform(action)
                }
                .focusable()
                .focused(focusedTarget, equals: .action(id: action.id))
            }
        }
        .padding(.horizontal, Theme.Menu.innerInset)
        .padding(.top, Theme.Menu.actionTopInset)
        .padding(.bottom, Theme.Menu.actionBottomInset)
        .accessibilityElement(children: .contain)
    }
}

private struct MenuBarActionRow: View {
    let action: MenuBarPanelContent.Action
    let perform: () -> Void
    @State private var isHovered = false
    @ScaledMetric(relativeTo: .body) private var rowHeight = Theme.Menu.actionHeight

    var body: some View {
        Button(action: perform) {
            HStack(spacing: Theme.Menu.actionGap) {
                Image(systemName: action.iconName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
                    .frame(width: Theme.Menu.actionIconSize, height: Theme.Menu.actionIconSize)
                    .accessibilityHidden(true)

                Text(action.title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if let shortcut = action.id.shortcut {
                    Text(shortcut.title)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Theme.Menu.actionRowInset)
            .frame(minHeight: rowHeight)
            .contentShape(.rect)
            .background(isHovered ? Theme.Menu.hoverFill : .clear,
                        in: .rect(cornerRadius: Theme.Metrics.controlRadius))
        }
        .buttonStyle(.plain)
        .modifier(MenuBarActionShortcut(actionID: action.id))
        .disabled(!action.isEnabled)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier("menu-bar-action-\(action.id.rawValue)")
    }
}

private struct MenuBarActionShortcut: ViewModifier {
    let actionID: MenuBarPanelActionID

    @ViewBuilder
    func body(content: Content) -> some View {
        if let shortcut = actionID.shortcut {
            content.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            content
        }
    }
}

private extension MenuBarPanelContent.Action {
    var iconName: String {
        switch id {
        case .pause:
            "pause.fill"
        case .resume:
            "play.fill"
        case .requestPermission:
            "hand.raised.fill"
        case .about:
            "info.circle.fill"
        case .openSystemSettings:
            "gearshape.fill"
        case .checkAgain:
            "arrow.clockwise.circle.fill"
        case .retryNow:
            "arrow.clockwise"
        case .continueSetup:
            "arrow.right.circle.fill"
        case .settings:
            "gearshape.fill"
        case .quit:
            "rectangle.portrait.and.arrow.right.fill"
        }
    }
}

#if DEBUG
#Preview("Menu-bar actions") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarActionList(
        actions: PreviewFixtures.panelActionList(),
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}

#Preview("Menu-bar actions paused") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarActionList(
        actions: PreviewFixtures.panelActionList(paused: true),
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
    .preferredColorScheme(.dark)
}
#endif
