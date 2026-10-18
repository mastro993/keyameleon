import AppIntents

struct GetActivePhysicalKeyboardIntent: AppIntent {
    static let title: LocalizedStringResource = "intentGetActiveKeyboard"

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some ReturnsValue<ActivePhysicalKeyboardEntity> {
        let entity = ActivePhysicalKeyboardEntity()
        entity.keyboard = switching.outcome.activePhysicalKeyboard?.name
        entity.inputSource = switching.outcome.currentInputSourceName
        return .result(value: entity)
    }
}
