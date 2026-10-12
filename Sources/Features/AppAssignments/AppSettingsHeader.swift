import SwiftUI

@MainActor
struct AppSettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(.appsHeaderTitle)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            Text(.appsHeaderDescription)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("App settings header") {
    AppSettingsHeader()
        .padding(16)
        .frame(width: 620)
        .background(Theme.contentBackground)
}
#endif
