import AppKit
import SwiftUI

@MainActor
struct CompactAboutView: View {
    private let model: GeneralSettingsModel
    private let identity: AppIdentity

    init(
        model: GeneralSettingsModel,
        identity: AppIdentity = .current
    ) {
        self.model = model
        self.identity = identity
    }

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .accessibilityLabel("Keyameleon app icon")

            Text(identity.name)
                .font(.title)
                .bold()

            Text(identity.versionLabel)
                .foregroundStyle(.secondary)

            Button("Check for Updates…", action: model.checkForUpdates)
                .disabled(!model.canCheckForUpdates)
                .padding(.top)

            LicensesButton()

            Spacer(minLength: 0)

            Text("Made with ❤️ by [@fedemas](https://x.com/fedemas)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#if DEBUG
#Preview("Compact About") {
    CompactAboutView(
        model: PreviewFixtures.general(),
        identity: PreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
}

#Preview("Compact About, dark, updates unavailable") {
    CompactAboutView(
        model: PreviewFixtures.general(canCheckForUpdates: false),
        identity: PreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
    .preferredColorScheme(.dark)
}

#Preview("Compact About, large text") {
    CompactAboutView(
        model: PreviewFixtures.general(),
        identity: PreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
