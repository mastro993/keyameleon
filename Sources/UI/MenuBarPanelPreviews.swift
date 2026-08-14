#if DEBUG
import SwiftUI

#Preview("Panel glass / light") {
    MenuBarPanelChromePreview(reduceTransparency: false, increasedContrast: false)
        .preferredColorScheme(.light)
}

#Preview("Panel opaque / dark") {
    MenuBarPanelChromePreview(reduceTransparency: true, increasedContrast: false)
        .preferredColorScheme(.dark)
}

#Preview("Panel contrast + long names") {
    MenuBarPanelChromePreview(
        reduceTransparency: false,
        increasedContrast: true,
        names: [
            "Keychron K2 HE ISO Nordic Traveler Custom Mechanical",
            "HHKB Professional Hybrid Type-S"
        ]
    )
}

#Preview("Panel five assignments") {
    MenuBarPanelChromePreview(count: 5)
}

#Preview("Panel overflow assignments") {
    MenuBarPanelChromePreview(count: 6)
}

private struct MenuBarPanelChromePreview: View {
    var reduceTransparency = false
    var increasedContrast = false
    var count = 0
    var names: [String] = []

    var body: some View {
        let chrome = MenuBarPanelChrome.resolve(
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        let keyboards = previewKeyboards()
        VStack(alignment: .leading, spacing: 0) {
            MenuBarAssignmentSection(
                list: MenuBarAssignmentList(
                    physicalKeyboards: keyboards,
                    assignedInputSourceNames: Dictionary(
                        uniqueKeysWithValues: keyboards.map { keyboard in
                            (keyboard.id, "Italian")
                        }
                    )
                ),
                emphasis: chrome.assignmentEmphasis
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            HStack {
                Text("Keyameleon 0.1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
            }
        }
        .frame(width: MenuBarPanelLayout.panelWidth)
        .background(
            chrome.surface == .opaque
                ? Color(nsColor: .windowBackgroundColor)
                : Color.clear
        )
    }

    private func previewKeyboards() -> [PhysicalKeyboard] {
        if !names.isEmpty {
            return names.enumerated().map { index, name in
                previewKeyboard(name: name, identifier: "kb-\(index)", isActive: index == 0)
            }
        }
        if count == 0 {
            return []
        }
        return (1...count).map { index in
            previewKeyboard(
                name: "Board \(index)",
                identifier: "board-\(index)",
                isActive: index == 1
            )
        }
    }

    private func previewKeyboard(
        name: String,
        identifier: String,
        isActive: Bool
    ) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: PhysicalKeyboardRecordID(rawValue: identifier),
            productName: name,
            customName: nil,
            transport: .usb,
            isBuiltIn: false,
            assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "it")!),
            connectedServiceCount: 1,
            connectionState: .connected,
            isActive: isActive
        )
    }
}
#endif
