import SwiftUI

/// The actions one Keyboards settings row offers.
@MainActor
struct KeyboardSettingsRowActions {
    let chooseInputSource: () -> Void
    let removeAssignment: () -> Void
    let rename: () -> Void
    let replace: () -> Void
    let forget: () -> Void
    let exclude: () -> Void
    let startManualDesignation: () -> Void
}

@MainActor
struct KeyboardSettingsRowView: View {
    let row: KeyboardSettingsRow
    let actions: KeyboardSettingsRowActions

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.title3)
                .foregroundStyle(row.warningText == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.headline)
                    if row.isActive {
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }

                Text(row.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let warningText = row.warningText {
                    Text(warningText)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                if let guidanceText = row.guidanceText {
                    Text(guidanceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            if let control = row.inputSourceControl {
                inputSourceButton(control)
            }

            if row.hasActions {
                actionsMenu
            }
        }
        .keyameleonCard(isHighlighted: row.isActive)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
        .accessibilityValue(row.accessibilityValue)
    }

    private func inputSourceButton(_ control: KeyboardSettingsRow.InputSourceControl) -> some View {
        Button(action: actions.chooseInputSource) {
            Text(control.title)
                .foregroundStyle(
                    control.needsAttention ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary)
                )
        }
        .buttonStyle(.bordered)
        .help(helpText(for: control))
        .accessibilityLabel("Input Source for \(row.name)")
        .accessibilityValue(control.title)
    }

    private var actionsMenu: some View {
        Menu {
            if row.canRename {
                Button("Rename…", action: actions.rename)
            }
            if row.hasAssignment {
                Button("Remove Assignment", action: actions.removeAssignment)
            }
            if row.canReplace {
                Button("Replace Saved Physical Keyboard…", action: actions.replace)
            }
            if row.canStartManualDesignation {
                Button("Manual Physical Keyboard Designation…", action: actions.startManualDesignation)
            }
            if row.canForget || row.canExclude {
                Divider()
            }
            if row.canForget {
                Button("Forget…", role: .destructive, action: actions.forget)
            }
            if row.canExclude {
                Button("Not a Keyboard…", action: actions.exclude)
                    .accessibilityIdentifier("not-a-keyboard")
                    .accessibilityHint("Removes \(row.name) from the Physical Keyboards list.")
            }
        } label: {
            Image(systemName: "ellipsis")
                .accessibilityLabel("Actions for \(row.name)")
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Actions for \(row.name)")
    }

    private func helpText(for control: KeyboardSettingsRow.InputSourceControl) -> String {
        switch control {
        case .assign:
            "Choose the Input Source \(row.name) selects"
        case .change:
            "Change the Input Source \(row.name) selects"
        case .unavailable:
            """
            This Keyboard Assignment's Input Source is not on this Mac. \
            Choose another Input Source, or add this one in System Settings.
            """
        }
    }
}

#if DEBUG
@MainActor
private struct KeyboardSettingsRowPreviewHost: View {
    let row: KeyboardSettingsRow

    var body: some View {
        KeyboardSettingsRowView(
            row: row,
            actions: KeyboardSettingsRowActions(
                chooseInputSource: {},
                removeAssignment: {},
                rename: {},
                replace: {},
                forget: {},
                exclude: {},
                startManualDesignation: {}
            )
        )
        .padding(12)
        .frame(width: 520)
    }
}

private func previewRow(
    _ physicalKeyboard: PhysicalKeyboard,
    assignedInputSourceName: String? = nil
) -> KeyboardSettingsRow {
    KeyboardSettingsRow(
        physicalKeyboard: physicalKeyboard,
        assignedInputSourceName: assignedInputSourceName,
        canReplace: false,
        canForget: true,
        canExclude: true,
        canStartManualDesignation: false
    )
}

#Preview("Row assigned and active") {
    KeyboardSettingsRowPreviewHost(
        row: previewRow(
            KeyameleonPreviewFixtures.physicalKeyboard(
                name: "Keychron K2",
                assignment: "com.apple.keylayout.Italian",
                isActive: true
            ),
            assignedInputSourceName: "Italian"
        )
    )
}

#Preview("Row unassigned") {
    KeyboardSettingsRowPreviewHost(
        row: previewRow(
            KeyameleonPreviewFixtures.physicalKeyboard(assignment: nil)
        )
    )
}

#Preview("Row unavailable Input Source") {
    KeyboardSettingsRowPreviewHost(
        row: previewRow(
            KeyameleonPreviewFixtures.physicalKeyboard(
                name: "Office Keyboard",
                assignment: "com.apple.keylayout.Gone"
            )
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Row unsupported identity") {
    KeyboardSettingsRowPreviewHost(
        row: previewRow(
            KeyameleonPreviewFixtures.unsupportedPhysicalKeyboard(reason: .ambiguousIdentity)
        )
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
