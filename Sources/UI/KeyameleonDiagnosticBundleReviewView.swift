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
            Text(KeyameleonAppMetadata.diagnosticBundleReviewTitle)
                .font(.headline)

            Text(KeyameleonAppMetadata.diagnosticBundleReviewExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)

            if summary.recordCount == 0 {
                Text(KeyameleonAppMetadata.diagnosticBundleNoData)
                    .foregroundStyle(.secondary)
            }

            diagnosticBundleSummary(summary)

            HStack {
                Button(KeyameleonAppMetadata.saveDiagnosticBundleButtonTitle) {
                    prepareFileExport()
                }
                .disabled(summary.recordCount == 0)
                .accessibilityLabel(KeyameleonAppMetadata.saveDiagnosticBundleButtonTitle)

                ShareLink(
                    item: DiagnosticBundleShareItem(data: model.diagnosticBundle.data),
                    preview: SharePreview(KeyameleonAppMetadata.diagnosticBundleSharePreviewTitle)
                ) {
                    Text(KeyameleonAppMetadata.shareDiagnosticBundleButtonTitle)
                }
                .disabled(summary.recordCount == 0)
                .accessibilityLabel(KeyameleonAppMetadata.shareDiagnosticBundleButtonTitle)
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
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: fileDocument,
            contentType: .json,
            defaultFilename: KeyameleonAppMetadata.diagnosticBundleDefaultFilename
        ) { result in
            if case .failure = result {
                saveError = KeyameleonAppMetadata.diagnosticBundleSaveFailedMessage
            }
        }
        .onAppear {
            model.refreshDiagnosticBundle()
        }
    }

    private func diagnosticBundleSummary(_ summary: DiagnosticBundleSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine(
                label: KeyameleonAppMetadata.diagnosticBundleIncludedCategoriesLabel,
                value: summary.includedCategories.isEmpty
                    ? KeyameleonAppMetadata.diagnosticBundleNoIncludedCategories
                    : summary.includedCategories.map(\.displayName).joined(separator: ", ")
            )
            summaryLine(
                label: KeyameleonAppMetadata.diagnosticBundleExcludedDataLabel,
                value: summary.excludedSensitiveData.joined(separator: ", ")
            )
            summaryLine(
                label: KeyameleonAppMetadata.diagnosticBundleDateRangeLabel,
                value: dateRangeDescription(summary.dateRange)
            )
            summaryLine(
                label: KeyameleonAppMetadata.diagnosticBundleRecordCountLabel,
                value: summary.recordCount.formatted()
            )
            summaryLine(
                label: KeyameleonAppMetadata.diagnosticBundleSizeLabel,
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
            return KeyameleonAppMetadata.diagnosticBundleNoDateRange
        }

        let start = dateRange.start.formatted(date: .abbreviated, time: .shortened)
        let end = dateRange.end.formatted(date: .abbreviated, time: .shortened)
        return start == end ? start : "\(start) – \(end)"
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
