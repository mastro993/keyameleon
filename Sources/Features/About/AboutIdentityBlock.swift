import AppKit
import SwiftUI

@MainActor
struct AboutIdentityBlock: View {
    let info: AboutInfo

    var body: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityLabel("Keyameleon app icon")
            VStack(alignment: .leading) {
                Text(info.identity.name)
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text("The right layout. On every keyboard.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("About identity block") {
    AboutIdentityBlock(info: PreviewFixtures.aboutInfo)
        .padding()
        .frame(width: 620, alignment: .leading)
}
#endif
