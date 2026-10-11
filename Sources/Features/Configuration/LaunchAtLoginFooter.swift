import ServiceManagement
import SwiftUI

@MainActor
struct LaunchAtLoginFooter: View {
    let hasError: Bool

    var body: some View {
        if hasError {
            VStack(alignment: .leading, spacing: 10) {
                Text(.launchAtLoginFailed)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.red)
                Button(.openLoginItems) { SMAppService.openSystemSettingsLoginItems() }
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
