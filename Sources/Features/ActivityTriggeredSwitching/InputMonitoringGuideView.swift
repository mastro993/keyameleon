import SwiftUI

struct InputMonitoringGuideView: View {
    let bundleURL: URL
    let close: () -> Void
    let draggingChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: Theme.Metrics.paneSpacing) {
            AppBundleDragSource(bundleURL: bundleURL, draggingChanged: draggingChanged)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: Theme.Metrics.navigationItemSpacing) {
                Text("Drag \(AppIdentity.current.name) into Input Monitoring")
                    .font(Theme.Typography.bodyStrong)
                    .foregroundStyle(Theme.primary)
                Text(
                    "If \(AppIdentity.current.name) is missing, drag this icon into the list. Enable its switch."
                )
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Show in Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
                    }
                    Button("Close", systemImage: "xmark", action: close)
                }
            }
        }
        .padding(Theme.Metrics.panePadding)
        .frame(width: 540, alignment: .leading)
        .background(Theme.windowBackground)
    }
}

#Preview("Input Monitoring guide — Light") {
    InputMonitoringGuideView(bundleURL: Bundle.main.bundleURL, close: {}, draggingChanged: { _ in })
        .preferredColorScheme(.light)
}

#Preview("Input Monitoring guide — Dark") {
    InputMonitoringGuideView(bundleURL: Bundle.main.bundleURL, close: {}, draggingChanged: { _ in })
        .preferredColorScheme(.dark)
}
