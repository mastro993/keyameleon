import AppKit
import SwiftUI

/// The Settings navigation sidebar: app identity over the three panes.
@MainActor
struct KeyameleonSettingsSidebar: View {
    let selection: KeyameleonSettingsSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            appIdentity
                .padding(.top, 28)
                .padding(.horizontal, 20)
            navigation
                .padding(.top, 24)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .frame(width: KeyameleonTheme.Metrics.sidebarWidth)
        .background(KeyameleonTheme.sidebarBackground, ignoresSafeAreaEdges: .all)
        .overlay(alignment: .trailing) {
            KeyameleonTheme.border.frame(width: 1).ignoresSafeArea()
        }
    }

    private var appIdentity: some View {
        HStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text(KeyameleonAppIdentity.current.name)
                .font(.body)
                .bold()
                .foregroundStyle(KeyameleonTheme.secondary)
        }
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: KeyameleonTheme.Metrics.navigationItemSpacing) {
            ForEach(KeyameleonSettingsSection.allCases) { section in
                navigationItem(for: section)
            }
        }
    }

    private func navigationItem(for section: KeyameleonSettingsSection) -> some View {
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
            .foregroundStyle(isSelected ? KeyameleonTheme.textOnAccent : KeyameleonTheme.primary)
            .padding(.horizontal, 10)
            .frame(height: KeyameleonTheme.Metrics.navigationItemHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? KeyameleonTheme.button : .clear,
                in: .rect(cornerRadius: KeyameleonTheme.Metrics.controlRadius, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview("Settings sidebar") {
    @Previewable @State var selection = KeyameleonSettingsSelection()
    KeyameleonSettingsSidebar(selection: selection)
        .frame(height: 400)
}
#endif
