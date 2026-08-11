import Foundation
import Combine

@MainActor
final class KeyameleonGeneralSettingsModel: ObservableObject {
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginError: LaunchAtLoginChangeError?
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var isDiagnosticSessionActive: Bool
    @Published private(set) var diagnosticRecordCount: Int
    @Published private(set) var diagnosticEstimatedByteCount: Int
    @Published private(set) var notificationAuthorizationState: OperationalNotificationAuthorizationState
    var onNotificationAuthorizationChange: (@MainActor () -> Void)?
    @Published private(set) var diagnosticBundle: DiagnosticBundle

    private let launchAtLoginController: any LaunchAtLoginControlling
    private let updateChecker: any UpdateChecking
    private let diagnosticDataController: any DiagnosticDataControlling
    private let operationalNotificationProvider: any OperationalNotificationProviding
    private let notificationSettingsOpener: any NotificationSettingsOpening
    private var isNotificationAuthorizationRequestInFlight = false

    init(
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        ),
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationSettingsOpener: any NotificationSettingsOpening =
            NoOpNotificationSettingsOpener()
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.updateChecker = updateChecker
        self.diagnosticDataController = diagnosticDataController
        self.operationalNotificationProvider = operationalNotificationProvider
        self.notificationSettingsOpener = notificationSettingsOpener
        self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        self.launchAtLoginError = nil
        self.canCheckForUpdates = updateChecker.canCheckForUpdates
        self.isDiagnosticSessionActive = diagnosticDataController.isDiagnosticSessionActive
        self.diagnosticRecordCount = diagnosticDataController.recordCount
        self.diagnosticEstimatedByteCount = diagnosticDataController.estimatedByteCount
        self.notificationAuthorizationState = operationalNotificationProvider.authorizationState
        self.onNotificationAuthorizationChange = nil
        self.diagnosticBundle = diagnosticDataController.makeDiagnosticBundle()
        diagnosticDataController.onChange = { [weak self] in
            self?.publishDiagnosticState()
        }
    }

    func refresh() {
        isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        canCheckForUpdates = updateChecker.canCheckForUpdates
        publishDiagnosticState()
        refreshNotificationAuthorization()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        switch launchAtLoginController.setEnabled(enabled) {
        case .success:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginError = nil
        case .failure:
            isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
            launchAtLoginError = .registrationFailed
        }
    }

    func checkForUpdates() {
        updateChecker.checkForUpdates()
        canCheckForUpdates = updateChecker.canCheckForUpdates
    }

    func requestOperationalNotificationAuthorization() {
        guard notificationAuthorizationState == .notDetermined,
              !isNotificationAuthorizationRequestInFlight
        else {
            return
        }

        isNotificationAuthorizationRequestInFlight = true
        operationalNotificationProvider.requestAlertAuthorization { [weak self] state in
            guard let self else {
                return
            }

            self.isNotificationAuthorizationRequestInFlight = false
            self.notificationAuthorizationState = state
            self.onNotificationAuthorizationChange?()
        }
    }

    func openNotificationSettings() {
        notificationSettingsOpener.openNotificationSettings()
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

    func refreshDiagnosticBundle() {
        publishDiagnosticState()
    }

    private func publishDiagnosticState() {
        isDiagnosticSessionActive = diagnosticDataController.isDiagnosticSessionActive
        diagnosticRecordCount = diagnosticDataController.recordCount
        diagnosticEstimatedByteCount = diagnosticDataController.estimatedByteCount
        diagnosticBundle = diagnosticDataController.makeDiagnosticBundle()
    }

    private func refreshNotificationAuthorization() {
        operationalNotificationProvider.refreshAuthorization { [weak self] state in
            self?.notificationAuthorizationState = state
        }
    }
}
