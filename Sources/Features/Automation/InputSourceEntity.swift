import AppIntents

/// An Eligible Input Source as Shortcuts shows and passes it.
struct InputSourceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intentInputSource")
    static let defaultQuery = InputSourceEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        // macOS already localizes Input Source names; the name fills a placeholder.
        DisplayRepresentation(title: "\(name)")
    }
}

extension InputSourceEntity {
    init(_ inputSource: EligibleInputSource) {
        self.init(id: inputSource.identifier, name: inputSource.name)
    }
}
