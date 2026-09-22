import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct KeyameleonDiagnosticBundleReviewView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    @State private var isShowingFileExporter = false
    @State private var fileDocument = DiagnosticBundleFileDocument(data: Data())
    @State private var saveError: String?

    init(
        model: KeyameleonGeneralSettingsModel,
        initialSaveError: String? = nil
    ) {
        _model = ObservedObject(wrappedValue: model)
        _saveError = State(initialValue: initialSaveError)
    }

    var body: some View {
        let summary = model.diagnosticBundle.summary

        Section("Diagnostic Bundle") {
            if summary.recordCount == 0 {
                Text("No Diagnostic Data retained.")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Included categories") {
                Text(
                    summary.includedCategories.isEmpty
                        ? "None"
                        : summary.includedCategories.map(diagnosticCategoryName).joined(separator: ", ")
                )
            }

            LabeledContent("Excluded sensitive data") {
                Text(summary.excludedSensitiveData.joined(separator: ", "))
            }

            LabeledContent("Date range") {
                Text(dateRangeDescription(summary.dateRange))
            }

            LabeledContent("Record count") {
                Text(summary.recordCount.formatted())
            }

            LabeledContent("Size") {
                Text(
                    ByteCountFormatter.string(
                        fromByteCount: Int64(summary.byteCount),
                        countStyle: .file
                    )
                )
            }

            HStack {
                Spacer()

                Button("Save Diagnostic Bundle") {
                    prepareFileExport()
                }
                .disabled(summary.recordCount == 0)
                .accessibilityLabel("Save Diagnostic Bundle…")

                ShareLink(
                    item: DiagnosticBundleShareItem(data: model.diagnosticBundle.data),
                    preview: SharePreview("Diagnostic Bundle")
                ) {
                    Text("Share Diagnostic Bundle…")
                }
                .disabled(summary.recordCount == 0)
                .accessibilityLabel("Share Diagnostic Bundle…")
            }

            if let saveError {
                Text(saveError)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("diagnostic-bundle-review")
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: fileDocument,
            contentType: .json,
            defaultFilename: "Keyameleon-Diagnostic-Bundle"
        ) { result in
            if case .failure = result {
                saveError = "Could not save Diagnostic Bundle."
            }
        }
        .onAppear {
            model.refreshDiagnosticBundle()
        }
    }

    private func dateRangeDescription(_ dateRange: DiagnosticBundleDateRange?) -> String {
        guard let dateRange else {
            return "No records"
        }

        let start = dateRange.start.formatted(date: .abbreviated, time: .shortened)
        let end = dateRange.end.formatted(date: .abbreviated, time: .shortened)
        return start == end ? start : "\(start) – \(end)"
    }

    private func diagnosticCategoryName(_ category: DiagnosticCategory) -> String {
        switch category {
        case .operationalError:
            "Operational errors"
        case .operationalStateChange:
            "Operational state changes"
        case .observationOrder:
            "Observation order"
        case .inputSourceSelectionResult:
            "Input Source selection results"
        case .sessionLifecycle:
            "Diagnostic Session lifecycle"
        }
    }

    private func prepareFileExport() {
        saveError = nil
        fileDocument = DiagnosticBundleFileDocument(data: model.diagnosticBundle.data)
        isShowingFileExporter = true
    }
}

struct DiagnosticBundleFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DiagnosticBundleShareItem: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { item in
            item.data
        }
    }
}

#if DEBUG
#Preview("Diagnostic bundle empty") {
    Form {
        KeyameleonDiagnosticBundleReviewView(
            model: KeyameleonPreviewFixtures.general()
        )
    }
    .formStyle(.grouped)
}

#Preview("Diagnostic bundle populated") {
    Form {
        KeyameleonDiagnosticBundleReviewView(
            model: KeyameleonPreviewFixtures.generalWithDiagnosticData()
        )
    }
    .formStyle(.grouped)
    .preferredColorScheme(.dark)
}

#Preview("Diagnostic bundle save error") {
    Form {
        KeyameleonDiagnosticBundleReviewView(
            model: KeyameleonPreviewFixtures.generalWithDiagnosticData(),
            initialSaveError: "Could not save Diagnostic Bundle."
        )
    }
    .formStyle(.grouped)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
