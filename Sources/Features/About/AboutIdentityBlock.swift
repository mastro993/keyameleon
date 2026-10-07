import AppKit
import SwiftUI

@MainActor
struct AboutIdentityBlock: View {
    let info: AboutInfo

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 48, height: 48)
                .accessibilityLabel("Keyameleon app icon")
            VStack(alignment: .leading, spacing: 5) {
                Text(info.identity.name)
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.primary)
                Text("The right layout. On every keyboard.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("About identity block") {
    AboutIdentityBlock(info: PreviewFixtures.aboutInfo)
        .padding()
        .frame(width: 620, alignment: .leading)
        .background(Theme.contentBackground)
}
#endif
