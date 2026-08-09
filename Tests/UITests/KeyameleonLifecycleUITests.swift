import XCTest

@MainActor
final class KeyameleonLifecycleUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 5
    private let menuTimeout: TimeInterval = 2
    private let windowTimeout: TimeInterval = 5

    func testLaunchOpenCloseReopenAndQuit() {
        let app = XCUIApplication(bundleIdentifier: "dev.fedemas.keyameleon")
        app.launchArguments = ["--reset-guided-setup"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Keyameleon"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: launchTimeout))

        let initialWindow = app.windows["Keyameleon"]
        XCTAssertTrue(initialWindow.waitForExistence(timeout: windowTimeout))
        XCTAssertTrue(app.staticTexts["Guided setup"].waitForExistence(timeout: menuTimeout))
        XCTAssertTrue(app.buttons["Request Permission"].waitForExistence(timeout: menuTimeout))
        closeWindow(initialWindow)

        statusItem.click()
        menuItem("Open Keyameleon…", in: statusItem).click()

        let window = app.windows["Keyameleon"]
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))
        closeWindow(window)

        statusItem.click()
        menuItem("Open Keyameleon…", in: statusItem).click()
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        statusItem.click()
        menuItem("Quit Keyameleon", in: statusItem).click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: launchTimeout))
    }

    private func menuItem(_ title: String, in statusItem: XCUIElement) -> XCUIElement {
        let item = statusItem.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: menuTimeout))
        return item
    }

    private func closeWindow(_ window: XCUIElement) {
        window.click()
        window.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(window.waitForExistence(timeout: menuTimeout))
    }
}
