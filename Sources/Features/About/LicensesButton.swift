import AppKit
import SwiftUI

/// One license text the app bundles for offline reading.
enum KeyameleonBundledLicense: String, Equatable, Sendable {
    case project = "LICENSE.txt"
    case sparkle = "Sparkle-LICENSE.txt"

    /// The bundled text, or nil when this build did not carry it.
    var url: URL? {
        Bundle.main.resourceURL?
            .appending(path: "Licenses", directoryHint: .isDirectory)
            .appending(path: rawValue)
    }

    @MainActor
    func open() {
        guard let url else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

/// Opens the folder of bundled license texts and third-party notices.
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
