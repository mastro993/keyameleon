import SwiftUI

@MainActor
struct AboutSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.sectionTitle)
            .foregroundStyle(Theme.primary)
    }
}

#if DEBUG
#Preview("About section heading") {
    AboutSectionHeading(title: "Information")
        .padding()
        .frame(width: 320, alignment: .leading)
        .background(Theme.contentBackground)
}
#endif
