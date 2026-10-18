import AppIntents

struct GetActivePhysicalKeyboardIntent: AppIntent {
    static let title: LocalizedStringResource = "intentGetActiveKeyboard"

    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func perform() async throws -> some ReturnsValue<ActivePhysicalKeyboardEntity> {
        // Like opening the menu: while paused, the current Input Source is not observed.
        switching.checkAgain()
        let entity = ActivePhysicalKeyboardEntity()
        entity.keyboard = switching.outcome.activePhysicalKeyboard?.name
        entity.inputSource = switching.outcome.currentInputSourceName
        return .result(value: entity)
    }
}
