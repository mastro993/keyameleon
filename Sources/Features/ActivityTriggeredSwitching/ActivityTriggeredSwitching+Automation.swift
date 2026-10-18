import Foundation

extension ActivityTriggeredSwitching {
    /// The Input Sources that Shortcuts and the URL scheme may select, as of
    /// the last refresh. Listing them in Shortcuts reads macOS no further.
    var automationInputSources: [EligibleInputSource] {
        inputSources.eligibleInputSources
    }

    /// Selects one Eligible Input Source for Shortcuts or the URL scheme.
    ///
    /// The selection counts as an External Input Source Change, like one made
    /// from the macOS menu bar, so the External Change Response decides what
    /// happens next.
    func selectInputSource(_ reference: AutomationCommand.InputSourceReference) throws(AutomationError) {
        inputSources.refresh()
        guard let inputSource = Self.inputSource(matching: reference, in: automationInputSources) else {
            switch reference {
            case let .identifier(text), let .name(text):
                throw .inputSourceUnavailable(text)
            }
        }

        let verified = inputSources.selectAndVerifyInputSource(identifier: inputSource.identifier)
        Log.debug(.switching, "Automation selected \(inputSource.identifier) (verified: \(verified))")
        // The observed Input Source stays the previous one, so this is seen as external.
        handleInputSourceModuleChange()
        guard verified else {
            throw .selectionFailed(inputSource.name)
        }
    }

    /// The exact identifier or name first. Otherwise a short identifier, the
    /// part after the last dot such as `US` for `com.apple.keylayout.US`,
    /// which stays the same in every language. A short identifier that fits
    /// more than one Input Source selects none, so nothing is substituted.
    private static func inputSource(
        matching reference: AutomationCommand.InputSourceReference,
        in inputSources: [EligibleInputSource]
    ) -> EligibleInputSource? {
        switch reference {
        case let .name(name):
            return inputSources.first { $0.name == name }
        case let .identifier(identifier):
            if let exact = inputSources.first(where: { $0.identifier == identifier }) {
                return exact
            }
            let short = inputSources.filter {
                $0.identifier.split(separator: ".").last?.caseInsensitiveCompare(identifier) == .orderedSame
            }
            return short.count == 1 ? short.first : nil
        }
    }
}
