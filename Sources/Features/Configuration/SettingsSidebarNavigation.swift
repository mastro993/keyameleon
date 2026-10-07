import SwiftUI

@MainActor
struct SettingsSidebarNavigation: View {
    @Bindable var selection: SettingsSelection

    var body: some View {
        List(selection: $selection.section) {
            ForEach(SettingsSection.allCases) { section in
                SettingsSidebarRow(
                    section: section,
                    isSelected: selection.section == section
                )
                .tag(section)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(
                    Theme.sidebarBackground
                        .overlay {
                            if selection.section == section {
                                RoundedRectangle(
                                    cornerRadius: Theme.Metrics.controlRadius,
                                    style: .continuous
                                )
                                .fill(Theme.button)
                                .padding(.bottom, Theme.Metrics.navigationItemSpacing)
                            }
                        }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tint(Theme.button)
        .contentMargins(.all, 0, for: .scrollContent)
        .padding(.horizontal, 12)
    }
}

#if DEBUG
#Preview("Settings sidebar navigation") {
    @Previewable @State var selection = SettingsSelection()
    SettingsSidebarNavigation(selection: selection)
        .frame(width: Theme.Metrics.sidebarWidth, height: 320)
        .background(Theme.sidebarBackground)
}
#endif
