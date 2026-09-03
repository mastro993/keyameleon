import AppKit
import SwiftUI

@MainActor
struct KeyameleonAboutView: View {
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
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityLabel("Keyameleon app icon")

            Text(identity.name)
                .font(.title2.weight(.semibold))
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)

            Text("Version \(identity.version)")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Text("GPL-3.0-only licensed open source.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.top, 5)

            Divider()
                .padding(.vertical, 24)
                .frame(maxWidth: 332)

            Button(action: model.checkForUpdates) {
                Label("Check for Updates…", systemImage: "arrow.clockwise.circle")
            }
            .controlSize(.regular)
            .disabled(!model.canCheckForUpdates)
            .accessibilityHint("Checks whether a newer Keyameleon version is available")

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
