import SwiftUI

/// The Apps pane: one row per App Assignment, and Add App….
@MainActor
struct AppSettingsPane: View {
    let model: AppAssignmentsModel
    let eligibleInputSources: [EligibleInputSource]

    var body: some View {
        Group {
            if model.rows.isEmpty && !model.hasPersistenceFailure {
                VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
                    AppSettingsHeader()
                    ContentUnavailableView {
                        Label(.appsEmptyTitle, systemImage: "square.grid.2x2")
                    } description: {
                        Text(.appsEmptyDescription)
                    } actions: {
                        AddAppMenu(model: model, eligibleInputSources: eligibleInputSources)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30))
            } else {
                AppAssignmentsList(model: model, eligibleInputSources: eligibleInputSources)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("app-assignments")
        .onAppear(perform: model.refresh)
    }
}

@MainActor
private struct AppAssignmentsList: View {
    let model: AppAssignmentsModel
    let eligibleInputSources: [EligibleInputSource]

    var body: some View {
        Form {
            Section {
                if model.hasPersistenceFailure {
                    AppAssignmentsFailureRow(model: model)
                        .listRowBackground(Theme.windowBackground)
                }
                ForEach(model.rows) { row in
                    AppAssignmentRowView(row: row, model: model, eligibleInputSources: eligibleInputSources)
                        .listRowBackground(Theme.windowBackground)
                }
                AddAppMenu(model: model, eligibleInputSources: eligibleInputSources)
                    .listRowBackground(Theme.windowBackground)
            } header: {
                AppSettingsHeader()
            } footer: {
                Text(.appsListFooter)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

@MainActor
private struct AppAssignmentsFailureRow: View {
    let model: AppAssignmentsModel

    var body: some View {
        VStack(alignment: .leading) {
            Text(.savedAppsUnavailable)
                .font(.headline)
            Text(.savedAppsClickRetry)
                .font(.callout)
            Button(.retry, action: model.refresh)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("app-assignments-unavailable")
    }
}

#if DEBUG
#Preview("Apps pane") {
    AppSettingsPane(model: PreviewFixtures.appAssignments(), eligibleInputSources: PreviewFixtures.inputSources())
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
}

#Preview("Apps pane empty") {
    AppSettingsPane(
        model: AppAssignmentsModel(store: InMemoryAppAssignmentStore(), apps: InMemoryInstalledApps()),
        eligibleInputSources: PreviewFixtures.inputSources()
    )
    .frame(width: 620, height: 560)
    .background(Theme.contentBackground)
    .preferredColorScheme(.dark)
}
#endif
