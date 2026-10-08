import SwiftUI

/// One read-only unsupported device: its name, how it connects, and why it is unsupported.
@MainActor
struct UnsupportedPhysicalKeyboardRow: View {
    let keyboard: PhysicalKeyboard

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(keyboard.name)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(Theme.muted)
                Text(subtitle)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Text(reason.title)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.secondary)
                .help(reason.explanation)
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
    UnsupportedPhysicalKeyboardRow(keyboard: PreviewFixtures.unsupportedPhysicalKeyboard())
        .padding()
        .frame(width: 630)
}
#endif
