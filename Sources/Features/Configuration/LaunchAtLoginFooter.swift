import ServiceManagement
import SwiftUI

@MainActor
struct LaunchAtLoginFooter: View {
    let hasError: Bool

    var body: some View {
        if hasError {
            VStack(alignment: .leading, spacing: 10) {
                Text("Couldn’t change this setting. macOS may need you to allow Keyameleon in Login Items.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.red)
                Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
            }
        }
    }
}

#if DEBUG
#Preview("Launch at login footer error") {
    LaunchAtLoginFooter(hasError: true)
        .padding()
        .frame(width: 420, alignment: .leading)
        .background(Theme.contentBackground)
        .preferredColorScheme(.dark)
}
#endif
