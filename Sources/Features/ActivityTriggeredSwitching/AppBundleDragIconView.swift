import AppKit

final class AppBundleDragIconView: NSImageView, NSDraggingSource {
    var bundleURL = Bundle.main.bundleURL
    var draggingChanged: (Bool) -> Void = { _ in }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    /// NSURL writes public.file-url, so the destination receives the actual
    /// running .app bundle rather than an icon image or a URL string.
    static func pasteboardWriter(for bundleURL: URL) -> any NSPasteboardWriting {
        bundleURL as NSURL
    }

    override func mouseDown(with event: NSEvent) {
        guard bundleURL.pathExtension == "app", let image else { return }
        let item = NSDraggingItem(pasteboardWriter: Self.pasteboardWriter(for: bundleURL))
        item.setDraggingFrame(bounds, contents: image)
        draggingChanged(true)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { .copy }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        draggingChanged(false)
    }
}
