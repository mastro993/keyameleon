import Foundation
import Combine

@MainActor
final class KeyameleonGeneralSettingsModel: ObservableObject {
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginErrorMessage: String?
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var isDiagnosticSessionActive: Bool
    @Published private(set) var diagnosticRecordCount: Int
    @Published private(set) var diagnosticEstimatedByteCount: Int
    @Published private(set) var diagnosticBundle: DiagnosticBundle

    private let launchAtLoginController: any LaunchAtLoginControlling
    private let updateChecker: any UpdateChecking
    private let diagnosticDataController: any DiagnosticDataControlling

    init(
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        )
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.updateChecker = updateChecker
        self.diagnosticDataController = diagnosticDataController
        self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        self.launchAtLoginErrorMessage = nil
        self.canCheckForUpdates = updateChecker.canCheckForUpdates
        self.isDiagnosticSessionActive = diagnosticDataController.isDiagnosticSessionActive
        self.diagnosticRecordCount = diagnosticDataController.recordCount
        self.diagnosticEstimatedByteCount = diagnosticDataController.estimatedByteCount
        self.diagnosticBundle = diagnosticDataController.makeDiagnosticBundle()
        diagnosticDataController.onChange = { [weak self] in
            self?.publishDiagnosticState()
        }
    }

    func refresh() {
        isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        canCheckForUpdates = updateChecker.canCheckForUpdates
        publishDiagnosticState()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        switch launchAtLoginController.setEnabled(enabled) {
        case .success:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginErrorMessage = nil
        case .failure:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginErrorMessage = KeyameleonAppMetadata.launchAtLoginErrorMessage
        }
    }

    func checkForUpdates() {
        updateChecker.checkForUpdates()
        canCheckForUpdates = updateChecker.canCheckForUpdates
    }

    func startDiagnosticSession() {
        diagnosticDataController.startDiagnosticSession()
        publishDiagnosticState()
    }

    func stopDiagnosticSession() {
        diagnosticDataController.stopDiagnosticSession()
        publishDiagnosticState()
    }

    func clearAllDiagnosticData() {
        diagnosticDataController.clearAllDiagnosticData()
        publishDiagnosticState()
    }

    private func publishDiagnosticState() {
        isDiagnosticSessionActive = diagnosticDataController.isDiagnosticSessionActive
        diagnosticRecordCount = diagnosticDataController.recordCount
        diagnosticEstimatedByteCount = diagnosticDataController.estimatedByteCount
        diagnosticBundle = diagnosticDataController.makeDiagnosticBundle()
    }
}
