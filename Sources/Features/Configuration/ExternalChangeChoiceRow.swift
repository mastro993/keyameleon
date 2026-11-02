import SwiftUI

/// One selectable row in the External Change Response Section: a small visual,
/// a title, one line of explanation, and the selected mark.
@MainActor
struct ExternalChangeChoiceRow: View {
    let choice: ExternalChangeChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ExternalChangeChoiceVisual(response: choice.response)

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(choice.caption)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.muted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(choice.title))
        .accessibilityHint(Text(choice.caption))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

#if DEBUG
#Preview("External change rows") {
    Form {
        Section {
            ForEach(ExternalChangeChoice.all) { choice in
                ExternalChangeChoiceRow(
                    choice: choice,
                    isSelected: choice.response == .switchBack,
                    action: {}
                )
                .listRowBackground(Theme.windowBackground)
            }
        } header: {
            Text(.externalChangeTitle)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
                .textCase(nil)
        }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .frame(width: 620, height: 260)
    .background(Theme.contentBackground)
}
#endif
