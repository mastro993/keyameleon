import SwiftUI

struct KeyameleonRootView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(KeyameleonAppMetadata.displayName)
                .font(.title)
                .accessibilityAddTraits(.isHeader)

            Text("Keyameleon menu bar shell is ready.")
                .foregroundStyle(.secondary)

            Text("Activity-Triggered Switching will appear here in a later release.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
        .frame(minWidth: 460, minHeight: 280)
    }
}
