import XCTest

@MainActor
final class KeyameleonLifecycleUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 5
    private let menuTimeout: TimeInterval = 2
    private let windowTimeout: TimeInterval = 5

    func testLaunchOpenCloseReopenAndQuit() {
        let app = XCUIApplication(bundleIdentifier: "dev.fedemas.keyameleon")
        app.launch()

        let statusItem = app.menuBars.statusItems["Keyameleon"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(app.windows.count, 0)

        statusItem.click()
        menuItem("Open Keyameleon…", in: app).click()

        let window = app.windows["Keyameleon"]
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        let closeButton = window.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: menuTimeout))
        closeButton.click()
        XCTAssertFalse(window.waitForExistence(timeout: menuTimeout))

        statusItem.click()
        menuItem("Open Keyameleon…", in: app).click()
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        statusItem.click()
        menuItem("Quit Keyameleon", in: app).click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: launchTimeout))
    }

    private func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let item = app.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: menuTimeout))
        return item
    }
}
