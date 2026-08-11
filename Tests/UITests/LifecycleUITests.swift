import XCTest

#if DEBUG
private let keyameleonBundleIdentifier = "dev.fedemas.keyameleon.development"
#else
private let keyameleonBundleIdentifier = "dev.fedemas.keyameleon"
#endif

@MainActor
final class KeyameleonLifecycleUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 5
    private let menuTimeout: TimeInterval = 2
    private let windowTimeout: TimeInterval = 5

    func testLaunchOpenCloseReopenAndQuit() {
        let app = XCUIApplication(bundleIdentifier: keyameleonBundleIdentifier)
        app.launchArguments = ["--reset-guided-setup"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Keyameleon"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: launchTimeout))

        let initialWindow = app.windows["Keyameleon"]
        XCTAssertTrue(initialWindow.waitForExistence(timeout: windowTimeout))
        XCTAssertTrue(app.staticTexts["Guided setup"].waitForExistence(timeout: menuTimeout))
        XCTAssertTrue(app.buttons["Request Permission"].waitForExistence(timeout: menuTimeout))
        XCTAssertTrue(
            initialWindow.descendants(matching: .any)["guided-setup"]
                .waitForExistence(timeout: menuTimeout)
        )
        XCTAssertTrue(
            initialWindow.descendants(matching: .any)["switching-status"]
                .waitForExistence(timeout: menuTimeout)
        )
        closeWindow(initialWindow)

        statusItem.click()
        clickMenuItem("Open Keyameleon…", in: statusItem)

        let window = app.windows["Keyameleon"]
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        closeWindow(window)

        statusItem.click()
        clickMenuItem("Open Keyameleon…", in: statusItem)
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        statusItem.click()
        let quitItem = statusItem.menuItems["Quit Keyameleon"]
        XCTAssertTrue(quitItem.waitForExistence(timeout: menuTimeout))
        app.typeKey("q", modifierFlags: .command)
        if !app.wait(for: .notRunning, timeout: 2) {
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: launchTimeout))
        }
    }

    private func clickMenuItem(_ title: String, in statusItem: XCUIElement) {
        let item = statusItem.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: menuTimeout))
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func closeWindow(_ window: XCUIElement) {
        window.click()
        window.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(window.isHittable)
    }
}
