import Foundation
import SwiftData
import Testing
@testable import Keyameleon

@Test("Storage failure keeps permission, pause, and lifecycle controls responsive")
@MainActor
private func persistenceFailureKeepsStatusControlsResponsive() {
    let session = SwiftDataPersistenceSession(openContainer: {
        throw CocoaError(.fileReadUnknown)
    })
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let eventObserver = SetupModelTestPhysicalKeyboardEventObserver()
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .denied),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: session),
        physicalKeyboardEventObserver: eventObserver,
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    startAndCheck(model)
    model.beginGuidedSetup()
    model.requestPermission()
    let switching = model.activityTriggeredSwitching
    #expect(switching.persistenceError != nil)
    #expect(switching.outcome.switchingStatus == .ready)
    #expect(model.guidedSetupStep == .assignments)

    switching.pause()
    #expect(switching.outcome.switchingStatus == .paused)
    #expect(switching.outcome.hasAction(.resume))
    switching.resume()
    #expect(switching.outcome.switchingStatus == .ready)
    #expect(switching.outcome.hasAction(.pause))

    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 907)))
    #expect(switching.testingPhysicalKeyboardDiscovery.physicalKeyboards.count == 1)
    switching.handleLifecycleEvent(.willSleep)
    #expect(switching.outcome.switchingStatus == .temporarilyUnavailable)
    #expect(switching.testingPhysicalKeyboardDiscovery.physicalKeyboards.isEmpty)
    switching.handleLifecycleEvent(.didWake)
    #expect(switching.outcome.switchingStatus == .ready)
    #expect(eventObserver.startCount == 0)
    #expect(switching.persistenceError != nil)
}

@Test("Retry Now checks saved data before selecting an Input Source")
@MainActor
private func retrySelectionReadFailureDoesNotSelect() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = false
    let session = SwiftDataPersistenceSession(modelContext: ModelContext(container), beforeFetch: {
        if fails { throw CocoaError(.fileReadUnknown) }
    })
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.italian", verifySuccess: false)
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardDiscoverer: discoverer,
        inputSourceProvider: SetupModelTestInputSourceProvider(inputSources: [
            EligibleInputSource(identifier: "com.example.us", name: "U.S."),
            EligibleInputSource(identifier: "com.example.italian", name: "Italian")
        ]),
        inputSourceSelector: selector,
        physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: session),
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    startAndCheck(model)
    discoverer.emit(.connected(makeSetupModelHardwareFacts(serviceID: 908)))
    let keyboard = try #require(model.physicalKeyboards.first)
    model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: "com.example.us")
    let switching = model.activityTriggeredSwitching
    switching.testingPhysicalKeyboardDiscovery.handlePhysicalKeyboardEventForTesting(
        PhysicalKeyboardEvent(serviceID: 908, kind: .press)
    )
    #expect(selector.selectCount == 1)
    #expect(switching.outcome.hasAction(.retryNow))
    selector.verifySuccess = true
    fails = true
    switching.retryNow()
    #expect(switching.persistenceError != nil)
    #expect(selector.selectCount == 1)
    #expect(selector.current == "com.example.italian")
    #expect(switching.testingVerifiedKeyboardAssignmentIdentifier == nil)
    fails = false
    model.retryPersistenceOperation()
    switching.retryNow()
    #expect(selector.selectCount == 2)
    #expect(selector.current == "com.example.us")
}

@Test("Native menu hides an empty failed keyboard list and routes saved-data Retry")
@MainActor
private func nativeMenuRetriesPersistenceFailure() throws {
    let container = try SwiftDataPhysicalKeyboardRecordStore.makeContainer(inMemory: true)
    var fails = true
    let session = SwiftDataPersistenceSession(openContainer: {
        if fails { throw CocoaError(.fileReadUnknown) }
        return container
    })
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        protectedStateProvider: ProtectedStateTestProvider(state: .clear),
        setupStore: SetupModelTestSetupDecisionStore(),
        systemSettingsOpener: SetupModelTestSystemSettingsOpener(),
        physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: session),
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    startAndCheck(model)
    #expect(model.hasPersistenceFailure)
    let controller = MenuBarPanelController(
        setupModel: model,
        switching: model.activityTriggeredSwitching,
        actions: MenuBarPanelActions(openAbout: {}, continueSetup: {}, openSettings: {}, quit: {})
    )
    let menu = controller.menu
    #expect(menu.items.allSatisfy { $0.view == nil })
    let retry = try #require(menu.items.firstIndex { $0.title == "Retry" })
    #expect(menu.items[retry].representedObject as? String == MenuBarPanelActionID.retryPersistence.rawValue)
    #expect(menu.items.first { $0.title == "Retry Now" } == nil)

    fails = false
    menu.performActionForItem(at: retry)
    #expect(model.hasPersistenceFailure == false)
    controller.refresh()
    #expect(menu.items.filter { $0.view != nil }.count == 1)
}
