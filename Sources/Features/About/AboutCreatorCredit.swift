import SwiftUI

@MainActor
struct AboutCreatorCredit: View {
    var body: some View {
        HStack {
            Text("Made with ❤️ by")
            Link("@fedemas", destination: AboutInfo.creatorURL)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("About creator credit") {
    AboutCreatorCredit()
        .padding()
        .frame(width: 320)
}
#endif
