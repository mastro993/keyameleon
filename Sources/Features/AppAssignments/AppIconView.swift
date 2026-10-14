import AppKit
import SwiftUI

/// The app's Finder icon, or a placeholder when the app is not installed.
@MainActor
struct AppIconView: View {
    let url: URL?

    var body: some View {
        if let url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
    }

    /// A menu item draws an `NSImage` at its own size, so menus get a sized copy.
    static func menuImage(for url: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

#if DEBUG
#Preview("App icon") {
    HStack {
        AppIconView(url: URL(filePath: "/System/Applications/Utilities/Terminal.app"))
        AppIconView(url: nil)
    }
    .frame(width: 80, height: 32)
    .padding()
}
#endif
