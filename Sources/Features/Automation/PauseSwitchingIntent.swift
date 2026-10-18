import AppIntents

struct PauseSwitchingIntent: AppIntent {
    static let title: LocalizedStringResource = "pauseSwitching"

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some IntentResult {
        try AutomationCommand.pause.perform(on: switching)
        return .result()
    }
}
