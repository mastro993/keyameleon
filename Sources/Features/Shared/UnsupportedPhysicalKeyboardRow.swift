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
                .help(Text(reason.explanation))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(reason.explanation)
    }

    private var subtitle: String {
        let isConnected = keyboard.connectionState == .connected
        let status = String(localized: isConnected ? .connectionConnected : .connectionDisconnected)
        return "\(keyboard.connectionTypeName) · \(status)"
    }

    private var reason: (title: LocalizedStringResource, explanation: LocalizedStringResource) {
        guard case let .unsupported(reason) = keyboard.assignmentState else {
            return (.unsupportedReasonUnknown, .unsupportedReasonUnknownHelp)
        }
        return switch reason {
        case .missingIdentity:
            (.unsupportedReasonMissingIdentity, .unsupportedReasonMissingIdentityHelp)
        case .unstableIdentity:
            (.unsupportedReasonUnstableIdentity, .unsupportedReasonUnstableIdentityHelp)
        case .sharedIdentity:
            (.unsupportedReasonSharedIdentity, .unsupportedReasonSharedIdentityHelp)
        case .ambiguousIdentity:
            (.unsupportedReasonAmbiguousIdentity, .unsupportedReasonAmbiguousIdentityHelp)
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
