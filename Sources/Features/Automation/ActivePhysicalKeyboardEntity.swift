import AppIntents

/// The Active Physical Keyboard and the current Input Source, by name.
struct ActivePhysicalKeyboardEntity: TransientAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intentActiveKeyboardAndInputSource")

    @Property(title: "intentKeyboard")
    var keyboard: String?

    @Property(title: "intentInputSource")
    var inputSource: String?

    init() {}

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: keyboard.map { LocalizedStringResource(stringLiteral: $0) } ?? .intentNoActiveKeyboard,
            subtitle: inputSource.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }
}
