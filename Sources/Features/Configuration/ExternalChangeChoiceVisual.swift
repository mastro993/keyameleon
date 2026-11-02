import SwiftUI

/// The compact visual in one External Change Response row. It shows the current
/// layout and which keyboard ends the hold; the row title and caption carry the
/// full meaning for VoiceOver.
struct ExternalChangeChoiceVisual: View {
    let response: ExternalChangeResponse

    var body: some View {
        Group {
            switch response {
            case .switchBack:
                HStack(spacing: 5) {
                    CurrentLayoutBadge()
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                    KeyboardReleaseChip(code: "IT", ends: nil)
                }

            case .holdUntilMatch:
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        CurrentLayoutBadge()
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                    HStack(spacing: 4) {
                        KeyboardReleaseChip(code: "US", ends: true)
                        KeyboardReleaseChip(code: "DE", ends: false)
                    }
                }

            case .holdUntilKeyboardChange:
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        CurrentLayoutBadge()
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                    HStack(spacing: 4) {
                        KeyboardReleaseChip(code: "US", ends: true)
                        KeyboardReleaseChip(code: "DE", ends: true)
                    }
                }
            }
        }
        .frame(width: 126, height: 46)
        .accessibilityHidden(true)
    }
}

private struct CurrentLayoutBadge: View {
    var body: some View {
        Text(verbatim: "US")
            .font(Theme.Typography.chip)
            .foregroundStyle(Theme.textOnAccent)
            .padding(.horizontal, 4)
            .frame(minWidth: 22, minHeight: 15)
            .background(Theme.button, in: RoundedRectangle(cornerRadius: 3))
    }
}

private struct KeyboardReleaseChip: View {
    let code: String
    /// nil: a plain keyboard; true: ends the hold; false: does not end it.
    let ends: Bool?

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "keyboard")
                .font(.caption2)
            Text(verbatim: code)
                .font(Theme.Typography.chip)
            if let ends {
                Image(systemName: ends ? "checkmark" : "xmark")
                    .font(.caption2)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 4)
        .frame(height: 18)
        .background(background, in: RoundedRectangle(cornerRadius: 3))
    }

    private var foreground: Color {
        guard let ends else { return Theme.secondary }
        return ends ? Theme.successText : Theme.muted
    }

    private var background: Color {
        guard let ends else { return Theme.chip }
        return ends ? Theme.success.opacity(0.14) : Theme.chip
    }
}

#Preview("External change visuals") {
    VStack(spacing: 10) {
        ForEach(ExternalChangeResponse.allCases, id: \.self) { response in
            ExternalChangeChoiceVisual(response: response)
        }
    }
    .padding(20)
    .background(Theme.contentBackground)
}
