import AppKit
import SwiftUI

@MainActor
struct KeyameleonLicensesButton: View {
    private let licensesURL = Bundle.main.resourceURL?
        .appending(path: "Licenses", directoryHint: .isDirectory)

    var body: some View {
        Button("Licenses and Notices") {
            if let licensesURL {
                NSWorkspace.shared.open(licensesURL)
            }
        }
        .disabled(licensesURL == nil)
        .help("Opens the bundled project license and complete third-party notices for offline reading.")
    }
}

#if DEBUG
#Preview("Licenses and notices") {
    KeyameleonLicensesButton()
        .padding()
}
#endif
