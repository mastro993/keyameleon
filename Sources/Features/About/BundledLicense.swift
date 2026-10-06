import AppKit

/// One license text the app bundles for offline reading.
enum BundledLicense: String, Equatable, Sendable {
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
