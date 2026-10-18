import AppKit
import XCTest
@testable import Keyameleon

final class ApplicationAutomationTests: XCTestCase {
    /// macOS delivers the URL that launches Keyameleon before it finishes
    /// launching; starting switching still sees that selection as external.
    @MainActor
    func testURLThatLaunchesKeyameleonSelectsOnceSwitchingStarts() throws {
        let setupStore = ApplicationTestSetupDecisionStore()
        setupStore.setExternalChangeResponse(.holdUntilKeyboardChange)
        let inputSources = ApplicationTestInputSources(
            sources: [
                EligibleInputSource(identifier: "com.example.us", name: "U.S."),
                EligibleInputSource(identifier: "com.example.italian", name: "Italian"),
            ],
            current: "com.example.us"
        )
        let delegate = makeApplicationTestDelegate(setupStore: setupStore, inputSources: inputSources)
        let url = try XCTUnwrap(URL(string: "keyameleon://select-input-source?id=com.example.italian"))

        delegate.application(NSApplication.shared, open: [url])
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        XCTAssertEqual(inputSources.current, "com.example.italian")
        XCTAssertEqual(delegate.activityTriggeredSwitching.outcome.inputSourceHold, .holdUntilKeyboardChange)
    }
}
