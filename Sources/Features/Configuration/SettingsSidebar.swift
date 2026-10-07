import SwiftUI

/// The Settings navigation sidebar: app identity over the native section list.
@MainActor
struct SettingsSidebar: View {
    let selection: SettingsSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSidebarIdentity()
                .padding(.top, Theme.Metrics.sidebarTopInset)
                .padding(.horizontal, 20)
            SettingsSidebarNavigation(selection: selection)
                .padding(.top, 24)
        }
        .frame(width: Theme.Metrics.sidebarWidth)
        .background(Theme.sidebarBackground, ignoresSafeAreaEdges: .all)
        .overlay(alignment: .trailing) {
            Theme.border.frame(width: 1).ignoresSafeArea()
        }
    }
}

#if DEBUG
#Preview("Settings sidebar") {
    @Previewable @State var selection = SettingsSelection()
    SettingsSidebar(selection: selection)
        .frame(height: 400)
}
#endif
