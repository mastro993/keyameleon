import SwiftUI

@MainActor
struct LaunchAtLoginFooter: View {
    let hasError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyameleon runs quietly in your menu bar.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)

            if hasError {
                Text(
                    """
                    Could not change Launch at Login. Open System Settings → General → \
                    Login Items if macOS requires approval.
                    """
                )
                .font(Theme.Typography.caption)
                .foregroundStyle(.red)
            }
        }
    }
}

#if DEBUG
#Preview("Launch at login footer") {
    LaunchAtLoginFooter(hasError: false)
        .padding()
        .frame(width: 420, alignment: .leading)
        .background(Theme.contentBackground)
}

#Preview("Launch at login footer error") {
    LaunchAtLoginFooter(hasError: true)
        .padding()
        .frame(width: 420, alignment: .leading)
        .background(Theme.contentBackground)
        .preferredColorScheme(.dark)
}
#endif
