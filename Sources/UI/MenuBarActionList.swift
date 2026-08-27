import SwiftUI

/// Full-width tray actions styled like compact native menu rows.
struct MenuBarActionList: View {
    let actions: [MenuBarPanelContent.Action]
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.22)

            ForEach(actions) { action in
                if action.id == .quit {
                    Divider()
                        .opacity(0.22)
                }

                MenuBarActionRow(action: action) {
                    perform(action)
                }
                .focusable()
                .focused(focusedTarget, equals: .action(id: action.id))
            }
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
    }
}

private struct MenuBarActionRow: View {
    let action: MenuBarPanelContent.Action
    let perform: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 13) {
                Image(systemName: action.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                Text(action.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 36)
            .contentShape(.rect)
            .background(isHovered ? Color.primary.opacity(0.08) : .clear)
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
        switch actionID {
        case .settings:
            content.keyboardShortcut(",", modifiers: .command)
        case .quit:
            content.keyboardShortcut("q", modifiers: .command)
        default:
            content
        }
    }
}

private extension MenuBarPanelContent.Action {
    var iconName: String {
        switch id {
        case .pause:
            "pause.circle"
        case .resume:
            "play.circle"
        case .requestPermission:
            "hand.raised"
        case .openKeyameleon:
            "keyboard"
        case .openSystemSettings:
            "gearshape"
        case .checkAgain:
            "arrow.clockwise"
        case .settings:
            "gearshape"
        case .quit:
            "rectangle.portrait.and.arrow.right"
        }
    }
}
