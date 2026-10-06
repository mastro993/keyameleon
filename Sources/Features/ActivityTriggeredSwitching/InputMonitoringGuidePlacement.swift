import AppKit

enum InputMonitoringGuidePlacement {
    /// Window Server coordinates start at the primary display's top left,
    /// even when the Settings window is on a display above or left of it.
    static func appKitRect(from windowBounds: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: windowBounds.minX,
            y: primaryDisplayHeight - windowBounds.maxY,
            width: windowBounds.width,
            height: windowBounds.height
        )
    }

    static func frame(
        below settingsFrame: CGRect,
        panelSize: NSSize,
        visibleFrames: [CGRect]
    ) -> CGRect? {
        guard let screen = visibleFrames.max(by: {
            overlap($0, settingsFrame) < overlap($1, settingsFrame)
        }) else { return nil }

        let gap = Theme.Metrics.paneSpacing
        let size = NSSize(
            width: min(panelSize.width, screen.width),
            height: min(panelSize.height, screen.height)
        )
        var origin = CGPoint(
            x: settingsFrame.midX - size.width / 2,
            y: settingsFrame.minY - gap - size.height
        )
        if origin.y < screen.minY {
            origin.y = settingsFrame.midY - size.height / 2
            origin.x = settingsFrame.maxX + gap
            if origin.x + size.width > screen.maxX {
                origin.x = settingsFrame.minX - gap - size.width
            }
        }
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        origin.y = min(max(origin.y, screen.minY), screen.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }

    private static func overlap(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    static func fallbackFrame(panelSize: NSSize, visibleFrames: [CGRect]) -> CGRect? {
        guard let screen = visibleFrames.first else { return nil }
        let size = NSSize(
            width: min(panelSize.width, screen.width),
            height: min(panelSize.height, screen.height)
        )
        return CGRect(
            x: screen.midX - size.width / 2,
            y: screen.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
