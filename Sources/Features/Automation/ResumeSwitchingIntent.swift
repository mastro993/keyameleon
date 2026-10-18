import AppIntents

struct ResumeSwitchingIntent: AppIntent {
    static let title: LocalizedStringResource = "resumeSwitching"

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some IntentResult {
        try AutomationCommand.resume.perform(on: switching)
        return .result()
    }
}
