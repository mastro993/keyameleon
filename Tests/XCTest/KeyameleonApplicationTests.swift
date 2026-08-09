import AppKit
import XCTest
@testable import Keyameleon

final class KeyameleonApplicationTests: XCTestCase {
    @MainActor
    func testMenuContainsOpenAndQuitActions() {
        let delegate = KeyameleonApplicationDelegate()
        let menu = delegate.makeMenu()

        XCTAssertEqual(
            menu.items.map(\.title),
            [
                KeyameleonAppMetadata.openMenuItemTitle,
                "",
                KeyameleonAppMetadata.quitMenuItemTitle,
            ]
        )
        XCTAssertTrue(menu.items[0].target === delegate)
        XCTAssertTrue(menu.items[2].target === delegate)
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
