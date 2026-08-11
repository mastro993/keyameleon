import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct KeyameleonDiagnosticBundleReviewView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    @State private var isShowingFileExporter = false
    @State private var fileDocument = DiagnosticBundleFileDocument(data: Data())
    @State private var saveError: String?

    init(model: KeyameleonGeneralSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        let summary = model.diagnosticBundle.summary

        VStack(alignment: .leading, spacing: 12) {
            Text("Review Diagnostic Bundle")
                .font(.headline)

            Text(
                "Review included Diagnostic Data and exclusions before you save or share. Each action is explicit."
            )
                .font(.callout)
                .foregroundStyle(.secondary)

            if summary.recordCount == 0 {
                Text("No Diagnostic Data retained.")
                    .foregroundStyle(.secondary)
            }

            diagnosticBundleSummary(summary)

            HStack {
                Button("Save Diagnostic Bundle…") {
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
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

    private func diagnosticBundleSummary(_ summary: DiagnosticBundleSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine(
                label: "Included categories",
                value: summary.includedCategories.isEmpty
                    ? "None"
                    : summary.includedCategories.map(diagnosticCategoryName).joined(separator: ", ")
            )
            summaryLine(
                label: "Excluded sensitive data",
                value: summary.excludedSensitiveData.joined(separator: ", ")
            )
            summaryLine(
                label: "Date range",
                value: dateRangeDescription(summary.dateRange)
            )
            summaryLine(
                label: "Record count",
                value: summary.recordCount.formatted()
            )
            summaryLine(
                label: "Size",
                value: ByteCountFormatter.string(
                    fromByteCount: Int64(summary.byteCount),
                    countStyle: .file
                )
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func summaryLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
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
