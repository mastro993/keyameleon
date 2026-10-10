import ServiceManagement
import SwiftUI

/// Explains a failed Launch at login change and opens Login Items.
@MainActor
struct LaunchAtLoginErrorRow: View {
    var body: some View {
        LabeledContent {
            Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
        } label: {
            Text("Couldn’t change this setting")
            Text("macOS may need you to allow Keyameleon in Login Items.")
        }
    }
}

#if DEBUG
#Preview("Launch at login error") {
    Form {
        LaunchAtLoginErrorRow()
    }
    .formStyle(.grouped)
    .frame(width: 520)
}
#endif
