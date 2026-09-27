import SwiftUI

@MainActor
struct OnboardingPhysicalKeyboardCard: View {
    let physicalKeyboard: PhysicalKeyboard
    let assignedInputSourceName: String?
    let onAssign: () -> Void
    let onExclude: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(physicalKeyboard.name)
                    .font(.headline)
                Spacer()
                Text(connectionLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(assignmentLabel)
                .font(.callout)
                .foregroundStyle(physicalKeyboard.isAssignable ? Color.secondary : Color.orange)

            HStack {
                if physicalKeyboard.isAssignable {
                    Button(
                        assignedInputSourceName == nil ? "Assign Input Source" : "Change Input Source",
                        action: onAssign
                    )
                }

                if let onExclude {
                    Button("Not a Keyboard", action: onExclude)
                        .accessibilityIdentifier("not-a-keyboard")
                        .accessibilityLabel("Not a Keyboard")
                        .accessibilityHint(
                            "Excludes \(physicalKeyboard.name) from Activity-Triggered Switching. "
                                + "You can include it again during onboarding or in Settings."
                        )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(physicalKeyboard.name)
        .accessibilityValue("\(connectionLabel). \(assignmentLabel)")
    }

    private var connectionLabel: String {
        switch physicalKeyboard.connectionState {
        case .connected:
            "Connected"
        case .disconnected:
            "Disconnected"
        }
    }

    private var assignmentLabel: String {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            "No Input Source assigned"
        case .assigned:
            if let assignedInputSourceName {
                assignedInputSourceName
            } else {
                "Unavailable Keyboard Assignment"
            }
        case let .unsupported(reason):
            unsupportedReasonName(reason)
        }
    }

    private func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
        switch reason {
        case .missingIdentity:
            "Unsupported — Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Unsupported — Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Unsupported — Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Unsupported — Physical Keyboard Identity ambiguous"
        }
    }
}

@MainActor
struct OnboardingExcludedPhysicalKeyboardCard: View {
    let exclusion: SavedPhysicalKeyboardExclusion
    let onIncludeAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exclusion.name)
                    .font(.headline)
                Spacer()
                Text("Excluded")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Does not trigger Activity-Triggered Switching")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Include Again", action: onIncludeAgain)
                .accessibilityIdentifier("include-excluded-device-again")
                .accessibilityLabel("Include \(exclusion.name) again")
                .accessibilityHint("Adds this device back to the Physical Keyboards list.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(exclusion.name)
        .accessibilityValue("Excluded. Does not trigger Activity-Triggered Switching.")
    }
}

#if DEBUG
#Preview("Onboarding included keyboard card") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(),
        assignedInputSourceName: "Italian",
        onAssign: {},
        onExclude: {}
    )
    .frame(width: 520)
}

#Preview("Onboarding excluded keyboard card") {
    OnboardingExcludedPhysicalKeyboardCard(
        exclusion: SavedPhysicalKeyboardExclusion(
            key: "identity:preview.keyboard",
            name: "Travel Keyboard"
        ),
        onIncludeAgain: {}
    )
    .frame(width: 520)
}
#endif
