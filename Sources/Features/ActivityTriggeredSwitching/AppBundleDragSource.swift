import SwiftUI

struct AppBundleDragSource: NSViewRepresentable {
    let bundleURL: URL
    let draggingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> AppBundleDragIconView {
        let view = AppBundleDragIconView()
        updateNSView(view, context: context)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setAccessibilityLabel("Keyameleon application")
        view.setAccessibilityHelp("Drag this application into the Input Monitoring list, or use Show in Finder.")
        return view
    }

    func updateNSView(_ view: AppBundleDragIconView, context: Context) {
        view.bundleURL = bundleURL
        view.draggingChanged = draggingChanged
        view.image = NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}
