import SwiftUI

@MainActor
struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage(isSelected: isSelected))
                .frame(width: 16)
                .foregroundStyle(isSelected ? Theme.textOnAccent : Theme.primary)
            Text(section.title)
                .font(
                    isSelected
                        ? Theme.Typography.navigationLabelSelected
                        : Theme.Typography.body
                )
                .foregroundStyle(isSelected ? Theme.textOnAccent : Theme.primary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: Theme.Metrics.navigationItemHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Theme.Metrics.navigationItemSpacing)
        .contentShape(.rect)
    }
}

#if DEBUG
#Preview("Settings sidebar row") {
    SettingsSidebarRow(section: .general, isSelected: true)
        .padding(12)
        .frame(width: Theme.Metrics.sidebarWidth, alignment: .leading)
        .background(Theme.sidebarBackground)
}
#endif
