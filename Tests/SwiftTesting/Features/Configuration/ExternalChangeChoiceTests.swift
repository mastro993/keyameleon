import Testing
@testable import Keyameleon

@Test("Every External Change Response has one card, in display order")
func externalChangeChoicesCoverEveryResponse() {
    #expect(ExternalChangeChoice.all.map(\.response) == ExternalChangeResponse.allCases)
}

@Test("Each External Change Response maps to its own card")
func externalChangeChoiceLookupMatchesResponse() {
    for response in ExternalChangeResponse.allCases {
        #expect(ExternalChangeChoice.choice(for: response).response == response)
    }
}
