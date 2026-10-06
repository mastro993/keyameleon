import SwiftUI

struct MenuBarPanelNoticeView: View {
    let notice: MenuBarPanelNotice
    let perform: (MenuBarPanelActionID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Menu.sectionInset) {
            Text(notice.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(notice.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MenuBarNoticeButton(
                title: notice.action.title,
                isEnabled: notice.action.isEnabled
            ) {
                perform(notice.action.id)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Theme.Menu.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notice.tone == .warning ? Color.yellow.opacity(0.14) : Color.primary.opacity(0.05))
        .clipShape(.rect(cornerRadius: Theme.Menu.rowRadius))
        .padding(.horizontal, Theme.Menu.rowInset)
        .padding(.vertical, Theme.Menu.sectionInset)
        .frame(width: Theme.Menu.width)
    }
}

#if DEBUG
#Preview("Warning light") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Input Monitoring required",
            detail: "Enable Keyameleon in Input Monitoring.",
            action: .init(id: .openSystemSettings, title: "Open System Settings", isEnabled: true),
            tone: .warning
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.light)
}

#Preview("Warning dark") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Input Monitoring required",
            detail: "Enable Keyameleon in Input Monitoring.",
            action: .init(id: .openSystemSettings, title: "Open System Settings", isEnabled: true),
            tone: .warning
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.dark)
}

#Preview("Neutral light") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Input Source differs",
            detail: "Travel Keyboard is using Italian instead of U.S.",
            action: .init(id: .settings, title: "Open Settings", isEnabled: true),
            tone: .neutral
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.light)
}

#Preview("Neutral dark") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Input Source differs",
            detail: "Travel Keyboard is using Italian instead of U.S.",
            action: .init(id: .settings, title: "Open Settings", isEnabled: true),
            tone: .neutral
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.dark)
}

#Preview("Long notice light") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Saved Physical Keyboards unavailable",
            detail: """
            Saved Physical Keyboard information could not be read. \
            The saved assignment and keyboard names remain unchanged until the store is available again. \
            Retry to reopen the saved store and restore Activity-Triggered Switching.
            """,
            action: .init(id: .retryPersistence, title: "Retry", isEnabled: true),
            tone: .warning
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.light)
}

#Preview("Long notice dark") {
    MenuBarPanelNoticeView(
        notice: MenuBarPanelNotice(
            title: "Saved Physical Keyboards unavailable",
            detail: """
            Saved Physical Keyboard information could not be read. \
            The saved assignment and keyboard names remain unchanged until the store is available again. \
            Retry to reopen the saved store and restore Activity-Triggered Switching.
            """,
            action: .init(id: .retryPersistence, title: "Retry", isEnabled: true),
            tone: .warning
        ),
        perform: { _ in }
    )
    .preferredColorScheme(.dark)
}
#endif
