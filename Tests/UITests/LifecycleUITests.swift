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
        clickPanelButton("Open Keyameleon…", in: app)

        let window = app.windows["Keyameleon"]
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        closeWindow(window)

        statusItem.click()
        clickPanelButton("Open Keyameleon…", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: windowTimeout))

        statusItem.click()
        clickPanelButton("Quit Keyameleon", in: app)
        if !app.wait(for: .notRunning, timeout: 2) {
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: launchTimeout))
        }
    }

    private func clickPanelButton(_ title: String, in app: XCUIApplication) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: menuTimeout))
        button.click()
    }

    private func closeWindow(_ window: XCUIElement) {
        window.click()
        window.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(window.isHittable)
    }
}
