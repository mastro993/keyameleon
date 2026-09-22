import AppKit
import SwiftUI

@MainActor
struct KeyameleonCompactAboutView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    private let identity: KeyameleonAppIdentity

    init(
        model: KeyameleonGeneralSettingsModel,
        identity: KeyameleonAppIdentity = .current
    ) {
        _model = ObservedObject(wrappedValue: model)
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
    KeyameleonCompactAboutView(
        model: KeyameleonPreviewFixtures.general(),
        identity: KeyameleonPreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
}

#Preview("Compact About, dark, updates unavailable") {
    KeyameleonCompactAboutView(
        model: KeyameleonPreviewFixtures.general(canCheckForUpdates: false),
        identity: KeyameleonPreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
    .preferredColorScheme(.dark)
}

#Preview("Compact About, large text") {
    KeyameleonCompactAboutView(
        model: KeyameleonPreviewFixtures.general(),
        identity: KeyameleonPreviewFixtures.aboutInfo.identity
    )
    .frame(width: 360, height: 360)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
