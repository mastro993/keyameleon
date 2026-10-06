import AppKit
import SwiftUI
import Testing
@testable import Keyameleon

@Test("Input Monitoring drag writes the running application as a file URL")
@MainActor
func inputMonitoringDragWritesApplicationFileURL() throws {
    let bundleURL = URL(filePath: "/Applications/Keyameleon.app")
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let writer = AppBundleDragIconView.pasteboardWriter(for: bundleURL)
    #expect(pasteboard.writeObjects([writer]))
    let urls = try #require(pasteboard.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
    ) as? [URL])
    #expect(urls == [bundleURL])
    #expect(AppBundleDragIconView().acceptsFirstMouse(for: nil))
    #expect(!AppBundleDragIconView().mouseDownCanMoveWindow)
}

@Test("Guide placement converts the primary origin for displays above and left")
func inputMonitoringGuideUsesPrimaryDisplayOrigin() throws {
    let above = InputMonitoringGuidePlacement.appKitRect(
        from: CGRect(x: 100, y: -800, width: 800, height: 600), primaryDisplayHeight: 900
    )
    #expect(above == CGRect(x: 100, y: 1100, width: 800, height: 600))
    let left = InputMonitoringGuidePlacement.appKitRect(
        from: CGRect(x: -1300, y: 50, width: 800, height: 650), primaryDisplayHeight: 900
    )
    #expect(left.minY == 200)
    let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900),
                   CGRect(x: -1440, y: 0, width: 1440, height: 900),
                   CGRect(x: 0, y: 900, width: 1440, height: 900)]
    let abovePlacement = try #require(InputMonitoringGuidePlacement.frame(
        below: above, panelSize: NSSize(width: 540, height: 150), visibleFrames: screens
    ))
    #expect(screens[2].contains(abovePlacement))
    #expect(abovePlacement.maxY < above.minY)
    let leftPlacement = try #require(InputMonitoringGuidePlacement.frame(
        below: left, panelSize: NSSize(width: 540, height: 150), visibleFrames: screens
    ))
    #expect(screens[1].contains(leftPlacement))
    #expect(leftPlacement.maxY < left.minY)
}

@Test("Guide falls beside Settings when below is full and stays within its display")
func inputMonitoringGuideFallsBesideAndClamps() throws {
    let screen = CGRect(x: 0, y: 0, width: 1600, height: 950)
    let settings = CGRect(x: 100, y: 30, width: 700, height: 600)
    let beside = try #require(InputMonitoringGuidePlacement.frame(
        below: settings, panelSize: NSSize(width: 540, height: 180), visibleFrames: [screen]
    ))
    #expect(beside.minX > settings.maxX)
    #expect(screen.contains(beside))
    let crowded = try #require(InputMonitoringGuidePlacement.frame(
        below: CGRect(x: 900, y: -20, width: 700, height: 1000),
        panelSize: NSSize(width: 540, height: 180), visibleFrames: [screen]
    ))
    #expect(screen.contains(crowded))
    #expect(InputMonitoringGuidePlacement.frame(
        below: settings, panelSize: .zero, visibleFrames: []
    ) == nil)
    let fallback = try #require(InputMonitoringGuidePlacement.fallbackFrame(
        panelSize: NSSize(width: 1800, height: 1100), visibleFrames: [screen]
    ))
    #expect(fallback == screen)
}

@Test("Successful Settings launches reuse one guide; failure and granted access show none")
@MainActor
func inputMonitoringGuideRequiresSuccessfulLaunchAndMissingPermission() {
    let fixture = InputMonitoringGuideTestFixture()
    var launchSucceeds = false
    var grantCount = 0
    fixture.guide.onPermissionGranted = { grantCount += 1 }
    let opener = NSWorkspaceSystemSettingsOpener(guide: fixture.guide, openURL: { _ in launchSucceeds })
    opener.openSystemSettings()
    #expect(fixture.panels.isEmpty)
    #expect(grantCount == 0)
    launchSucceeds = true
    fixture.permission.state = .granted
    opener.openSystemSettings()
    #expect(fixture.panels.isEmpty)
    #expect(grantCount == 1)
    fixture.permission.state = .unknown
    opener.openSystemSettings()
    fixture.permission.state = .denied
    opener.openSystemSettings()
    #expect(fixture.panels.count == 1)
    #expect(fixture.panels.first?.orderCount == 2)
    opener.stop()
    #expect(fixture.panels.first?.closeCount == 1)
}

@Test("Actual permission grant refreshes switching and advances setup once")
@MainActor
func inputMonitoringGuideGrantRefreshesSetup() {
    let fixture = InputMonitoringGuideTestFixture()
    let model = SetupModel(
        permissionProvider: fixture.permission,
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener()
    )
    var grantCount = 0
    fixture.guide.onPermissionGranted = { [weak model] in
        grantCount += 1
        model?.activityTriggeredSwitching.checkAgain()
        model?.advanceIfPermissionGranted()
    }
    fixture.guide.show()
    fixture.guide.refresh()
    #expect(grantCount == 0)
    #expect(model.guidedSetupStep == .permission)
    fixture.permission.state = .granted
    fixture.guide.refresh()
    fixture.guide.refresh()
    #expect(grantCount == 1)
    #expect(model.activityTriggeredSwitching.outcome.switchingStatus == .ready)
    #expect(model.guidedSetupStep == .assignments)
    #expect(fixture.panels.first?.closeCount == 1)
}

@Test("Settings launch gets grace; metadata failure is not window closure")
@MainActor
func inputMonitoringGuideDistinguishesLaunchAndWindowClosure() {
    let fixture = InputMonitoringGuideTestFixture()
    fixture.window = .notRunning
    fixture.guide.show()
    fixture.date.addTimeInterval(4)
    fixture.guide.refresh()
    #expect(fixture.panels.first?.closeCount == 0)
    fixture.window = .window(CGRect(x: 100, y: 300, width: 800, height: 600))
    fixture.guide.refresh()
    fixture.window = .unavailable
    fixture.date.addTimeInterval(10)
    fixture.guide.refresh()
    #expect(fixture.panels.first?.closeCount == 0)
    fixture.window = .noWindow
    fixture.guide.refresh()
    #expect(fixture.panels.first?.closeCount == 1)
    fixture.window = .noWindow
    fixture.guide.show()
    fixture.date.addTimeInterval(5)
    fixture.guide.refresh()
    #expect(fixture.panels.last?.closeCount == 1)
    fixture.window = .unavailable
    fixture.guide.show()
    fixture.date.addTimeInterval(10)
    fixture.guide.refresh()
    #expect(fixture.panels.last?.closeCount == 0)
    fixture.window = .notRunning
    fixture.guide.refresh()
    #expect(fixture.panels.last?.closeCount == 1)
}

@Test("Reopening Settings renews launch grace without duplicating the guide")
@MainActor
func inputMonitoringGuideReopenRenewsLaunchGrace() {
    let fixture = InputMonitoringGuideTestFixture()
    fixture.guide.show()
    fixture.date.addTimeInterval(10)
    fixture.window = .notRunning
    fixture.guide.show()
    #expect(fixture.panels.count == 1)
    #expect(fixture.panels.first?.closeCount == 0)
    fixture.date.addTimeInterval(4)
    fixture.guide.refresh()
    #expect(fixture.panels.first?.closeCount == 0)
    fixture.window = .window(CGRect(x: 100, y: 300, width: 800, height: 600))
    fixture.guide.refresh()
    fixture.window = .notRunning
    fixture.guide.refresh()
    #expect(fixture.panels.first?.closeCount == 1)
}

@Test("Guide placement freezes during native application dragging")
@MainActor
func inputMonitoringGuideDoesNotMoveDuringDrag() throws {
    let fixture = InputMonitoringGuideTestFixture()
    fixture.guide.show()
    let panel = try #require(fixture.panels.first)
    let host = try #require(panel.contentView as? NSHostingView<InputMonitoringGuideView>)
    let frame = panel.frame
    host.rootView.draggingChanged(true)
    fixture.window = .window(CGRect(x: 500, y: 400, width: 800, height: 500))
    fixture.guide.refresh()
    #expect(panel.frame == frame)
    host.rootView.draggingChanged(false)
    fixture.guide.refresh()
    #expect(panel.frame != frame)
    fixture.guide.stop()
}

@Test("Close and shutdown stop grant callbacks; reopening starts a fresh session")
@MainActor
func inputMonitoringGuideDismissalStopsSession() {
    let fixture = InputMonitoringGuideTestFixture()
    var grantCount = 0
    fixture.guide.onPermissionGranted = { grantCount += 1 }
    fixture.guide.show()
    fixture.guide.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    fixture.permission.state = .granted
    fixture.guide.refresh()
    #expect(grantCount == 0)
    #expect(fixture.panels.first?.closeCount == 0)
    fixture.permission.state = .denied
    fixture.guide.show()
    #expect(fixture.panels.count == 2)
    fixture.guide.stop()
    fixture.guide.stop()
    #expect(fixture.panels.last?.closeCount == 1)
}

@MainActor
private final class InputMonitoringGuideTestFixture {
    let permission = SetupModelTestListenPermissionProvider(state: .denied)
    var window = InputMonitoringSettingsWindow.window(CGRect(x: 100, y: 300, width: 800, height: 600))
    var date = Date(timeIntervalSince1970: 0)
    var panels: [InputMonitoringGuideTestPanel] = []
    lazy var guide = InputMonitoringGuideController(
        permissionProvider: permission,
        snapshot: { [unowned self] in window },
        now: { [unowned self] in date },
        makePanel: { [unowned self] in
            let panel = InputMonitoringGuideTestPanel(
                contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panels.append(panel)
            return panel
        },
        visibleFrames: { [CGRect(x: 0, y: 0, width: 1600, height: 1000)] }
    )
}

@MainActor
private final class InputMonitoringGuideTestPanel: NSPanel {
    var orderCount = 0
    var closeCount = 0

    override func orderFront(_ sender: Any?) { orderCount += 1 }
    override func close() { closeCount += 1 }
}
