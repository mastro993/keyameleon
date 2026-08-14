import AppKit
import SwiftUI

/// One transient 320 pt menu-bar panel anchored to the existing status item.
///
/// Native macOS 26 Liquid Glass comes from `NSPopover` chrome. Callers must not
/// wrap this surface in extra glass cards.
@MainActor
final class KeyameleonMenuBarPanelController: NSObject, NSPopoverDelegate {
    static let panelWidth: CGFloat = MenuBarPanelContent.panelWidth

    private let popover = NSPopover()
    private let refresh: () -> Void
    private var lastClosedAt: Date?

    var isShown: Bool {
        popover.isShown
    }

    var behavior: NSPopover.Behavior {
        popover.behavior
    }

    var panelWidth: CGFloat {
        Self.panelWidth
    }

    init(rootView: some View, refresh: @escaping () -> Void) {
        self.refresh = refresh
        super.init()

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentSize = NSSize(width: Self.panelWidth, height: 1)
    }

    func show(from positioningView: NSView) {
        guard !popover.isShown else {
            return
        }

        refresh()
        var size = popover.contentSize
        size.width = Self.panelWidth
        popover.contentSize = size
        popover.show(
            relativeTo: positioningView.bounds,
            of: positioningView,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKey()
    }

    func close() {
        guard popover.isShown else {
            return
        }

        popover.performClose(nil)
    }

    func toggle(from positioningView: NSView) {
        if popover.isShown {
            close()
            return
        }

        // A status-item click while the transient popover is open closes it first.
        // Ignore that same click so the panel does not immediately reopen.
        if let lastClosedAt, Date().timeIntervalSince(lastClosedAt) < 0.25 {
            return
        }

        show(from: positioningView)
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        false
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosedAt = Date()
    }
}
