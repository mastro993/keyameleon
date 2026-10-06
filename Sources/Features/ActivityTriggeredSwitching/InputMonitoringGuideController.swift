import AppKit
import SwiftUI

@MainActor
final class InputMonitoringGuideController: NSObject, NSWindowDelegate {
    private enum Session {
        case launching(Date)
        case following
    }

    private let permissionProvider: any ListenPermissionProviding
    private let snapshot: @MainActor () -> InputMonitoringSettingsWindow
    private let now: () -> Date
    private let makePanel: () -> NSPanel
    private let visibleFrames: () -> [CGRect]
    private var session: Session?
    private var pollingTask: Task<Void, Never>?
    private var panel: NSPanel?
    private var isDragging = false
    var onPermissionGranted: (() -> Void)?

    init(
        permissionProvider: any ListenPermissionProviding,
        snapshot: @escaping @MainActor () -> InputMonitoringSettingsWindow = InputMonitoringSettingsWindow.snapshot,
        now: @escaping () -> Date = Date.init,
        makePanel: @escaping () -> NSPanel = {
            NSPanel(
                contentRect: .zero,
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
        },
        visibleFrames: @escaping () -> [CGRect] = { NSScreen.screens.map(\.visibleFrame) }
    ) {
        self.permissionProvider = permissionProvider
        self.snapshot = snapshot
        self.now = now
        self.makePanel = makePanel
        self.visibleFrames = visibleFrames
    }

    func show() {
        guard permissionProvider.checkListenPermission() != .granted else {
            stop()
            onPermissionGranted?()
            return
        }
        if let panel {
            session = .launching(now())
            panel.orderFront(nil)
            refresh()
            return
        }
        let panel = makePanel()
        panel.title = "Input Monitoring"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        let view = InputMonitoringGuideView(
            bundleURL: Bundle.main.bundleURL,
            close: { [weak self] in self?.stop() },
            draggingChanged: { [weak self] in self?.isDragging = $0 }
        )
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        if let fallback = InputMonitoringGuidePlacement.fallbackFrame(
            panelSize: panel.frame.size, visibleFrames: visibleFrames()
        ) {
            panel.setFrame(fallback, display: false)
        }
        self.panel = panel
        session = .launching(now())
        refresh()
        guard self.panel != nil else { return }
        panel.orderFront(nil)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(750))
                } catch { return }
                guard let self, self.session != nil, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard let session else { return }
        if permissionProvider.checkListenPermission() == .granted {
            stop()
            onPermissionGranted?()
            return
        }
        switch snapshot() {
        case .window(let frame):
            self.session = .following
            guard !isDragging, let panel,
                  let placement = InputMonitoringGuidePlacement.frame(
                    below: frame, panelSize: panel.frame.size, visibleFrames: visibleFrames()
                  ) else { return }
            panel.setFrame(placement, display: true)
        case .unavailable:
            // Keep the movable fallback when metadata cannot be read. Failure
            // to inspect a window is not evidence that the user closed it.
            break
        case .notRunning, .noWindow:
            switch session {
            case .following:
                stop()
            case .launching(let started):
                if now().timeIntervalSince(started) >= 5 { stop() }
            }
        }
    }

    func stop() {
        session = nil
        pollingTask?.cancel()
        pollingTask = nil
        isDragging = false
        let closingPanel = panel
        panel = nil
        closingPanel?.delegate = nil
        closingPanel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel?.delegate = nil
        panel = nil
        stop()
    }
}
