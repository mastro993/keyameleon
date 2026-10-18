import AppIntents

/// Selects one Input Source. It counts as an External Input Source Change,
/// so the External Change Response decides what happens next.
struct SelectInputSourceIntent: AppIntent {
    static let title: LocalizedStringResource = "intentSelectInputSource"

    @Parameter(title: "intentInputSource")
    var inputSource: InputSourceEntity

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some IntentResult {
        try AutomationCommand.selectInputSource(.identifier(inputSource.id)).perform(on: switching)
        return .result()
    }
}
