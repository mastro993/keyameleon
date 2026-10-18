import Foundation

/// Why Shortcuts or the URL scheme could not select an Input Source.
enum AutomationError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    /// No Eligible Input Source has this name or identifier; carries the caller's text.
    case inputSourceUnavailable(String)
    /// macOS did not keep the requested Input Source; carries its name.
    case selectionFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .inputSourceUnavailable(reference): .automationInputSourceUnavailable(reference)
        case let .selectionFailed(name): .automationSelectionFailed(name)
        }
    }
}
