import AppKit
import SwiftUI
import XCTest
@testable import Keyameleon

final class ApplicationBundleTests: XCTestCase {
    /// The hosted app is always a Debug build (ADR 0008).
    private var keyameleonBundle: Bundle? {
        Bundle(identifier: "dev.fedemas.keyameleon.debug")
    }

    @MainActor
    func testMenuBarIconFallbackMapsEveryStatusMark() {
        let delegate = makeApplicationTestDelegate()
        defer { stopApplicationTestSurface(delegate) }
        let expected: [(MenuBarIconMark, String, String)] = [
            (.ready, "keyboard", AppIdentity.current.name),
            (.permissionRequired, "keyboard.badge.ellipsis", "\(AppIdentity.current.name) — Permission Required"),
            (.temporarilyUnavailable, "moon.zzz", "\(AppIdentity.current.name) — Temporarily Unavailable"),
            (.paused, "pause.circle", "\(AppIdentity.current.name) — Paused"),
            (.warning, "exclamationmark.triangle", "\(AppIdentity.current.name) — Action needed")
        ]

        for (mark, symbolName, accessibilityDescription) in expected {
            XCTAssertEqual(delegate.systemSymbolName(for: mark), symbolName)
            XCTAssertEqual(
                delegate.menuBarIconAccessibilityDescription(for: mark),
                accessibilityDescription
            )
        }
    }

    @MainActor
    func testMenuBarIconUsesBundledPDFAtTemplateSize() throws {
        let delegate = makeApplicationTestDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer { stopApplicationTestSurface(delegate) }

        let image = try XCTUnwrap(delegate.menuBarStatusItem?.button?.image)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, AppIdentity.current.name)
        XCTAssertNotNil(keyameleonBundle?.url(forResource: "menu_icon", withExtension: "pdf"))
    }

    @MainActor
    func testLaunchedApplicationUsesAccessoryPolicyAndAgentInfo() {
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertEqual(
            keyameleonBundle?
                .object(forInfoDictionaryKey: "LSUIElement") as? Bool,
            true
        )
        XCTAssertEqual(
            keyameleonBundle?
                .object(forInfoDictionaryKey: "LSMultipleInstancesProhibited") as? Bool,
            true
        )
    }

    @MainActor
    func testSparkleInfoPlistEncodesUserApprovedUpdatePolicy() {
        let bundle = keyameleonBundle
        XCTAssertEqual(
            bundle?.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            UpdatePolicy.feedURLString
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
        XCTAssertEqual(
            bundle?.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? Int,
            Int(UpdatePolicy.minimumCheckInterval)
        )
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool, false)
        XCTAssertEqual(bundle?.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool, false)
    }
}
