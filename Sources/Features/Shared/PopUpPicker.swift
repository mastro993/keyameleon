import AppKit
import SwiftUI

/// The System Settings pop-up button: an `NSPopUpButton` with the
/// `.flexiblePush` bezel, which keeps its box visible at rest.
///
/// SwiftUI's `Picker` in a grouped `Form` shows that box only under the
/// pointer on macOS 26, so Settings rows host the AppKit control instead.
struct PopUpPicker: NSViewRepresentable {
    struct Option: Equatable {
        let title: String
        var isEnabled = true
    }

    /// Spoken by VoiceOver; the row shows its own visible label.
    let accessibilityLabel: String
    let options: [Option]
    /// Index into `options`, or nil when nothing is selected.
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .flexiblePush
        button.autoenablesItems = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        let titles = button.itemArray.map(\.title)
        if titles != options.map(\.title) {
            // Menu items rather than `addItem(withTitle:)`, which drops duplicate titles.
            button.menu?.removeAllItems()
            for option in options {
                button.menu?.addItem(NSMenuItem(title: option.title, action: nil, keyEquivalent: ""))
            }
        }
        for (item, option) in zip(button.itemArray, options) {
            item.isEnabled = option.isEnabled
        }
        button.selectItem(at: selectedIndex ?? -1)
        button.isEnabled = context.environment.isEnabled
        button.setAccessibilityLabel(accessibilityLabel)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> NSSize? {
        nsView.intrinsicContentSize
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelect: (Int) -> Void

        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard sender.indexOfSelectedItem >= 0 else { return }
            onSelect(sender.indexOfSelectedItem)
        }
    }
}

#if DEBUG
#Preview("Pop-up picker") {
    @Previewable @State var selected = 0
    Form {
        LabeledContent("Notifications") {
            PopUpPicker(
                accessibilityLabel: "Notifications",
                options: [.init(title: "Notification Center"), .init(title: "Banners")],
                selectedIndex: selected,
                onSelect: { selected = $0 }
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 520)
}
#endif
