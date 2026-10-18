import Foundation

/// One action that Shortcuts or the `keyameleon://` URL scheme asks for.
enum AutomationCommand: Equatable, Sendable {
    case pause
    case resume
    case togglePause
    case selectInputSource(InputSourceReference)
    case setExternalChangeResponse(ExternalChangeResponse)

    /// How a caller names the Input Source to select.
    enum InputSourceReference: Equatable, Sendable {
        case identifier(String)
        /// The exact name macOS shows, such as `U.S.`.
        case name(String)
    }

    /// Reads `keyameleon://pause`, `resume`, `toggle-pause`,
    /// `select-input-source?id=…` or `?name=…`, and
    /// `set-external-change-response?value=switch-back`, `hold-until-match`,
    /// or `hold-until-keyboard-change`. The scheme is not checked:
    /// macOS only delivers the one this build registers.
    init?(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        func value(_ name: String) -> String? {
            components?.queryItems?.first { $0.name == name }?.value?.nilIfEmpty
        }

        switch url.host()?.lowercased() {
        case "pause":
            self = .pause
        case "resume":
            self = .resume
        case "toggle-pause":
            self = .togglePause
        case "select-input-source":
            if let identifier = value("id") {
                self = .selectInputSource(.identifier(identifier))
            } else if let name = value("name") {
                self = .selectInputSource(.name(name))
            } else {
                return nil
            }
        case "set-external-change-response":
            let responses: [String: ExternalChangeResponse] = [
                "switch-back": .switchBack,
                "hold-until-match": .holdUntilMatch,
                "hold-until-keyboard-change": .holdUntilKeyboardChange
            ]
            guard let response = value("value").flatMap({ responses[$0] }) else {
                return nil
            }
            self = .setExternalChangeResponse(response)
        default:
            return nil
        }
    }

    @MainActor
    func perform(on switching: ActivityTriggeredSwitching) throws(AutomationError) {
        switch self {
        case .pause:
            switching.pause()
        case .resume:
            switching.resume()
        case .togglePause:
            // The same choice as the menu's Pause or Resume Switching command.
            if switching.outcome.hasAction(.resume) {
                switching.resume()
            } else {
                switching.pause()
            }
        case let .selectInputSource(reference):
            try switching.selectInputSource(reference)
        case let .setExternalChangeResponse(response):
            switching.setExternalChangeResponse(response)
        }
    }
}
