import SwiftUI

@MainActor
struct SettingsCard<Content: View, Footer: View>: View {
    private let title: String
    private let content: Content
    private let footer: Footer

    init(
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            content
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            footer
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

extension SettingsCard where Footer == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, content: content, footer: { EmptyView() })
    }
}

private struct SettingsCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

extension View {
    func settingsCardStyle() -> some View {
        modifier(SettingsCardStyle())
    }
}

#if DEBUG
#Preview("Settings card with footer") {
    @Previewable @State var launchAtLoginEnabled = true
    SettingsCard(title: "Startup") {
        Toggle("Launch Keyameleon at login", isOn: $launchAtLoginEnabled)
    } footer: {
        Text("Starts Keyameleon when you log in.")
    }
    .frame(width: 520)
}

#Preview("Settings card without footer") {
    SettingsCard(title: "Operational Notifications") {
        Text("Optional alerts for important state changes.")
    }
    .frame(width: 520)
    .preferredColorScheme(.dark)
}

#Preview("Settings card long content") {
    SettingsCard(title: "Diagnostic Session") {
        VStack(alignment: .leading, spacing: 12) {
            Text("Retention stops at 7 days or 5 MB.")
            Text(
                "Diagnostic Data never includes Key Content, serial numbers, custom names, assignments, paths, user names, or application names."
            )
        }
    } footer: {
        Text("Detailed Diagnostic Data is time-limited.")
    }
    .frame(width: 520)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
