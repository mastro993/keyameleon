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
