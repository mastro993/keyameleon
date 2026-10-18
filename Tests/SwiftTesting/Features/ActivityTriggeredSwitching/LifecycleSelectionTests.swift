import Testing
@testable import Keyameleon

@Test("Disconnecting the Active Physical Keyboard does not select the remaining Keyboard Assignment")
@MainActor
func disconnectingActivePhysicalKeyboardDoesNotSelectRemainingKeyboardAssignment() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        selector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 801,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-alpha"
            )
        )
    )
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 802,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-beta"
            )
        )
    )

    let alphaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }?.id)
    let betaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("beta") }?.id)
    model.setKeyboardAssignment(alphaID, inputSourceIdentifier: "com.example.us")
    model.setKeyboardAssignment(betaID, inputSourceIdentifier: "com.example.italian")
    driveActivationActivity(serviceID: 801, on: model)
    let selectCountBeforeDisconnect = selector.selectCount

    discoverer.emit(.disconnected(serviceID: 801))

    #expect(selector.selectCount == selectCountBeforeDisconnect)
    #expect(model.activePhysicalKeyboardID == alphaID)
    let beta = try #require(model.physicalKeyboards.first { $0.id == betaID })
    #expect(beta.connectionState == .connected)
    #expect(!beta.isActive)
}

@Test("Connecting an assigned Physical Keyboard does not select its Keyboard Assignment")
@MainActor
func connectingAssignedPhysicalKeyboardDoesNotSelectItsKeyboardAssignment() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        selector: selector
    )

    startAndCheck(model)
    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 801,
                identity: "macos.keyboard.alpha",
                serialNumber: "serial-alpha"
            )
        )
    )
    let alphaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }?.id)
    model.setKeyboardAssignment(alphaID, inputSourceIdentifier: "com.example.us")
    driveActivationActivity(serviceID: 801, on: model)

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 802,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-beta"
            )
        )
    )
    let betaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("beta") }?.id)
    model.setKeyboardAssignment(betaID, inputSourceIdentifier: "com.example.italian")
    discoverer.emit(.disconnected(serviceID: 802))
    let selectCountBeforeReconnect = selector.selectCount

    discoverer.emit(
        .connected(
            makeSetupModelHardwareFacts(
                serviceID: 802,
                identity: "macos.keyboard.beta",
                serialNumber: "serial-beta"
            )
        )
    )

    #expect(selector.selectCount == selectCountBeforeReconnect)
    #expect(model.activePhysicalKeyboardID == alphaID)
    let beta = try #require(model.physicalKeyboards.first { $0.id == betaID })
    #expect(beta.connectionState == .connected)
    #expect(!beta.isActive)
}

@Test("Wake and unlock do not select the Active Keyboard Assignment")
@MainActor
func wakeAndUnlockDoNotSelectActiveKeyboardAssignment() throws {
    let recordStore = InMemoryPhysicalKeyboardRecordStore()
    let discoverer = SetupModelTestPhysicalKeyboardDiscoverer()
    let selector = SetupModelTestInputSourceSelector(current: "com.example.us")
    let model = makeLifecycleModel(
        recordStore: recordStore,
        discoverer: discoverer,
        selector: selector
    )

    startAndCheck(model)
    let alphaFacts = makeSetupModelHardwareFacts(
        serviceID: 801,
        identity: "macos.keyboard.alpha",
        serialNumber: "serial-alpha"
    )
    discoverer.emit(.connected(alphaFacts))
    let alphaID = try #require(model.physicalKeyboards.first { $0.id.rawValue.contains("alpha") }?.id)
    model.setKeyboardAssignment(alphaID, inputSourceIdentifier: "com.example.italian")
    driveActivationActivity(serviceID: 801, on: model)
    #expect(selector.selectCount == 1)
    let selectCountAfterActivationActivity = selector.selectCount

    model.activityTriggeredSwitching.handleLifecycleEvent(.willSleep)
    model.activityTriggeredSwitching.handleLifecycleEvent(.didWake)
    discoverer.emit(.connected(alphaFacts))

    #expect(selector.selectCount == selectCountAfterActivationActivity)
    #expect(model.activePhysicalKeyboardID == alphaID)

    model.activityTriggeredSwitching.handleLifecycleEvent(.sessionDidResignActive)
    model.activityTriggeredSwitching.handleLifecycleEvent(.sessionDidBecomeActive)
    discoverer.emit(.connected(alphaFacts))

    #expect(selector.selectCount == selectCountAfterActivationActivity)
    #expect(model.activePhysicalKeyboardID == alphaID)
}

@MainActor
private func driveActivationActivity(serviceID: UInt64, on model: SetupModel) {
    model.activityTriggeredSwitching.testingPhysicalKeyboardDiscovery
        .handlePhysicalKeyboardEventForTesting(
            PhysicalKeyboardEvent(serviceID: serviceID, kind: .press)
        )
}
