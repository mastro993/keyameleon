import SwiftUI

/// One read-only unsupported device: its name, how it connects, and why it is unsupported.
@MainActor
struct UnsupportedPhysicalKeyboardRow: View {
    let keyboard: PhysicalKeyboard

    var body: some View {
        LabeledContent {
            Text(reason.title)
                .help(reason.explanation)
        } label: {
            Text(keyboard.name)
            Text(subtitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(reason.explanation)
    }

    private var subtitle: String {
        let status = keyboard.connectionState == .connected ? "Connected" : "Disconnected"
        return "\(keyboard.connectionTypeName) · \(status)"
    }

    private var reason: (title: String, explanation: String) {
        guard case let .unsupported(reason) = keyboard.assignmentState else {
            return ("Unsupported", "Keyameleon can’t recognize this device reliably.")
        }
        return switch reason {
        case .missingIdentity:
            ("No stable ID", "This device reports no serial number or other stable ID.")
        case .unstableIdentity:
            ("ID changes", "This device’s ID changes when it reconnects.")
        case .sharedIdentity:
            ("Shared ID", "Several connected devices of this model report the same ID.")
        case .ambiguousIdentity:
            ("Inconsistent ID", "This device reports a different ID on each of its interfaces.")
        }
    }
}

#if DEBUG
#Preview("Unsupported device row") {
    Form {
        UnsupportedPhysicalKeyboardRow(keyboard: PreviewFixtures.unsupportedPhysicalKeyboard())
    }
    .formStyle(.grouped)
    .frame(width: 630)
}
#endif
