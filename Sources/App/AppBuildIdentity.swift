import Foundation

enum AppBuildIdentity: Sendable {
    case production
    case development

    static let current: Self = {
        switch Bundle.main.bundleIdentifier {
        case "dev.fedemas.keyameleon": .production
        case "dev.fedemas.keyameleon.development": .development
        default: fatalError("Unexpected Keyameleon bundle identifier")
        }
    }()

    var storageFolderName: String {
        switch self {
        case .production: "Keyameleon"
        case .development: "Keyameleon (Dev)"
        }
    }

    var integrityKeyService: String {
        switch self {
        case .production: "dev.fedemas.keyameleon.installation-integrity"
        case .development: "dev.fedemas.keyameleon.development.installation-integrity"
        }
    }

    var singletonURL: URL {
        switch self {
        case .production: URL(fileURLWithPath: "/dev/null")
        case .development: URL(fileURLWithPath: "/dev/zero")
        }
    }

    var importsLegacyStore: Bool { self == .production }
    var allowsUpdates: Bool { self == .production }
}
