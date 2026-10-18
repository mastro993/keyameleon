import Foundation

extension ActivityTriggeredSwitching {
    /// The Input Sources that Shortcuts and the URL scheme may select, read
    /// fresh from macOS.
    func automationInputSources() -> [EligibleInputSource] {
        inputSources.refresh()
        return inputSources.eligibleInputSources
    }

    /// Selects one Eligible Input Source for Shortcuts or the URL scheme.
    ///
    /// The selection counts as an External Input Source Change, like one made
    /// from the macOS menu bar, so the External Change Response decides what
    /// happens next.
    func selectInputSource(_ reference: AutomationCommand.InputSourceReference) throws(AutomationError) {
        let inputSource = automationInputSources().first {
            switch reference {
            case let .identifier(identifier): $0.identifier == identifier
            case let .name(name): $0.name == name
            }
        }
        guard let inputSource else {
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
}
