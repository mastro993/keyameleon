import AppIntents

struct TogglePauseIntent: AppIntent {
    static let title: LocalizedStringResource = "intentTogglePause"

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some IntentResult {
        try AutomationCommand.togglePause.perform(on: switching)
        return .result()
    }
}
