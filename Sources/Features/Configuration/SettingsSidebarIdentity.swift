import SwiftUI

@MainActor
struct SettingsSidebarIdentity: View {
    var body: some View {
        HStack(spacing: 4) {
            Image("Keycap")
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text(AppIdentity.current.name)
                .font(Theme.Typography.bodyStrong)
                .foregroundStyle(Theme.secondary)
        }
    }
}

#if DEBUG
#Preview("Settings sidebar identity") {
    SettingsSidebarIdentity()
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.sidebarBackground)
}
#endif
