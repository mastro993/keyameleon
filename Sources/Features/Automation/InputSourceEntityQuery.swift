import AppIntents

struct InputSourceEntityQuery: EntityQuery {
    @Dependency private var switching: ActivityTriggeredSwitching

    @MainActor
    func entities(for identifiers: [InputSourceEntity.ID]) async throws -> [InputSourceEntity] {
        switching.automationInputSources
            .filter { identifiers.contains($0.identifier) }
            .map(InputSourceEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [InputSourceEntity] {
        switching.automationInputSources.map(InputSourceEntity.init)
    }
}
