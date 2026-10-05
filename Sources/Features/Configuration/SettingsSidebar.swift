import AppKit
import SwiftUI

/// The Settings navigation sidebar: app identity over the three panes.
@MainActor
struct SettingsSidebar: View {
    let selection: SettingsSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            appIdentity
                .padding(.top, Theme.Metrics.sidebarTopInset)
                .padding(.horizontal, 20)
            navigation
                .padding(.top, 24)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .frame(width: Theme.Metrics.sidebarWidth)
        .background(Theme.sidebarBackground, ignoresSafeAreaEdges: .all)
        .overlay(alignment: .trailing) {
            Theme.border.frame(width: 1).ignoresSafeArea()
        }
    }

    private var appIdentity: some View {
        HStack(spacing: 4) {
            Image("Keycap")
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text(AppIdentity.current.name)
                .font(.body)
                .bold()
                .foregroundStyle(Theme.secondary)
        }
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.navigationItemSpacing) {
            ForEach(SettingsSection.allCases) { section in
                navigationItem(for: section)
            }
        }
    }

    private func navigationItem(for section: SettingsSection) -> some View {
        let isSelected = selection.section == section
        return Button {
            selection.section = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.systemImage(isSelected: isSelected))
                    .frame(width: 17)
                Text(section.title)
                    .font(.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Theme.textOnAccent : Theme.primary)
            .padding(.horizontal, 10)
            .frame(height: Theme.Metrics.navigationItemHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Theme.button : .clear,
                in: .rect(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview("Settings sidebar") {
    @Previewable @State var selection = SettingsSelection()
    SettingsSidebar(selection: selection)
        .frame(height: 400)
}
#endif
