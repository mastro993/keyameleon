import Foundation

/// The Settings copy for one External Change Response row: its title and its
/// one-line explanation.
struct ExternalChangeChoice: Identifiable, Sendable {
    let response: ExternalChangeResponse
    let title: LocalizedStringResource
    let caption: LocalizedStringResource

    var id: ExternalChangeResponse { response }

    /// The display order: Switch back, Until matching keyboard, Until another
    /// keyboard. The first response is the default.
    static let all = ExternalChangeResponse.allCases.map(Self.choice(for:))

    static func choice(for response: ExternalChangeResponse) -> ExternalChangeChoice {
        switch response {
        case .switchBack:
            ExternalChangeChoice(
                response: .switchBack,
                title: .externalChangeSwitchBack,
                caption: .externalChangeSwitchBackCaption
            )
        case .holdUntilMatch:
            ExternalChangeChoice(
                response: .holdUntilMatch,
                title: .externalChangeHoldUntilMatch,
                caption: .externalChangeHoldUntilMatchCaption
            )
        case .holdUntilKeyboardChange:
            ExternalChangeChoice(
                response: .holdUntilKeyboardChange,
                title: .externalChangeHoldUntilKeyboardChange,
                caption: .externalChangeHoldUntilKeyboardChangeCaption
            )
        }
    }
}
