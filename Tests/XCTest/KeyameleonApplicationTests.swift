import AppKit
import XCTest
@testable import Keyameleon

final class KeyameleonApplicationTests: XCTestCase {
    @MainActor
    func testMenuContainsOpenAndQuitActions() {
        let delegate = KeyameleonApplicationDelegate()
        let menu = delegate.makeMenu()
        let titles = menu.items.map(\.title)

        XCTAssertTrue(titles.contains { $0.hasPrefix(KeyameleonAppMetadata.switchingStatusMenuItemPrefix) })
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.openMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.openSystemSettingsMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.checkAgainMenuItemTitle))
        XCTAssertTrue(titles.contains(KeyameleonAppMetadata.quitMenuItemTitle))
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.openMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.openSystemSettingsMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.checkAgainMenuItemTitle)?.target === delegate)
        XCTAssertTrue(menu.item(withTitle: KeyameleonAppMetadata.quitMenuItemTitle)?.target === delegate)
    }

    @MainActor
    func testClosingLastWindowDoesNotTerminateApplication() {
        let delegate = KeyameleonApplicationDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    @MainActor
    func testLaunchedApplicationUsesAccessoryPolicyAndAgentInfo() {
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertEqual(
            Bundle(identifier: KeyameleonAppMetadata.bundleIdentifier)?
                .object(forInfoDictionaryKey: "LSUIElement") as? Bool,
            true
        )
    }
}
