import SwiftUI

/// One App Assignment row: icon, name, Input Source, and a Remove action.
///
/// It mirrors `PhysicalKeyboardRowView` so both lists line up.
@MainActor
struct AppAssignmentRowView: View {
    let row: AppAssignmentRow
    let model: AppAssignmentsModel
    let eligibleInputSources: [EligibleInputSource]

    var body: some View {
        HStack(spacing: 16) {
            AppIconView(url: row.appURL)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.assignment.appName)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(row.isInstalled ? Theme.primary : Theme.muted)
                if !row.isInstalled {
                    Text(.appNotInstalled)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                InputSourceMenu(
                    title: String(localized: .inputSourceForKeyboard(row.assignment.appName)),
                    selection: Binding(
                        get: { row.assignment.inputSourceIdentifier },
                        set: { identifier in
                            guard let identifier else { return }
                            model.setInputSource(identifier, for: row)
                        }
                    ),
                    inputSources: eligibleInputSources,
                    allowsUnassigned: false
                )
                .disabled(eligibleInputSources.isEmpty || model.hasPersistenceFailure)
                Menu {
                    Button(.removeApp, systemImage: "minus.circle") {
                        model.remove(row)
                    }
                } label: {
                    Label(.appActions, systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                        .help(Text(.appActions))
                }
                .font(.body)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28)
                .disabled(model.hasPersistenceFailure)
                .accessibilityIdentifier("app-actions")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("App Assignment row") {
    let model = PreviewFixtures.appAssignments()
    Form {
        ForEach(model.rows) { row in
            AppAssignmentRowView(row: row, model: model, eligibleInputSources: PreviewFixtures.inputSources())
        }
    }
    .formStyle(.grouped)
    .frame(width: 620)
}
#endif
