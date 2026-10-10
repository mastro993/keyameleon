import SwiftUI

@MainActor
struct AboutCreatorCredit: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Made with ❤️ by")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
            Link(destination: AboutInfo.creatorURL) {
                Text("@fedemas")
                    .font(Theme.Typography.caption)
            }
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("About creator credit") {
    AboutCreatorCredit()
        .padding()
        .frame(width: 320)
        .background(Theme.contentBackground)
}
#endif
