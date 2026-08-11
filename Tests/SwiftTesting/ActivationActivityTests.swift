import Testing
@testable import Keyameleon

@Test("Normal press and repeat are Activation Activity; release is not")
func normalPressAndRepeatAreActivationActivityReleaseIsNot() {
    #expect(ActivationActivityClassification.isActivationActivity(.press))
    #expect(ActivationActivityClassification.isActivationActivity(.repeat))
    #expect(!ActivationActivityClassification.isActivationActivity(.release))
}

@Test("Element transitions map to press, repeat, and release without Key Content")
func elementTransitionsMapToPressRepeatAndRelease() {
    #expect(PhysicalKeyboardElementTransition.kind(previous: nil, current: 1) == .press)
    #expect(PhysicalKeyboardElementTransition.kind(previous: 0, current: 1) == .press)
    #expect(PhysicalKeyboardElementTransition.kind(previous: 1, current: 1) == .repeat)
    #expect(PhysicalKeyboardElementTransition.kind(previous: 1, current: 0) == .release)
    #expect(PhysicalKeyboardElementTransition.kind(previous: 0, current: 0) == nil)
    #expect(PhysicalKeyboardElementTransition.kind(previous: nil, current: 0) == nil)
}

@Test("Activation Activity event carries service attribution only")
func activationActivityEventCarriesServiceAttributionOnly() {
    let event = PhysicalKeyboardEvent(serviceID: 42, kind: .press)
    #expect(event.serviceID == 42)
    #expect(ActivationActivityClassification.isActivationActivity(event))
}
