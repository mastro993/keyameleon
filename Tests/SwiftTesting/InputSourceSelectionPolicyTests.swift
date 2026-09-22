import Testing
@testable import Keyameleon

@Test("Blank or whitespace Input Source identifier is rejected")
func blankIdentifierIsRejected() {
    #expect(InputSourceSelectionPolicy.prepare(identifier: "", current: "com.apple.keylayout.ABC") == .reject)
    #expect(InputSourceSelectionPolicy.prepare(identifier: "   ", current: "com.apple.keylayout.ABC") == .reject)
    #expect(InputSourceSelectionPolicy.prepare(identifier: "\n", current: nil) == .reject)
}

@Test("Identifier matching the current Input Source needs no select")
func matchingCurrentInputSourceIsAlreadyCurrent() {
    #expect(
        InputSourceSelectionPolicy.prepare(
            identifier: " com.apple.keylayout.ABC ",
            current: "com.apple.keylayout.ABC"
        ) == .alreadyCurrent
    )
}

@Test("Different current Input Source is captured as the previous one")
func differentCurrentInputSourceIsCapturedAsPrevious() {
    #expect(
        InputSourceSelectionPolicy.prepare(
            identifier: "com.apple.keylayout.ABC",
            current: "com.apple.keylayout.US"
        ) == .select(normalized: "com.apple.keylayout.ABC", previous: "com.apple.keylayout.US")
    )
}

@Test("No current Input Source selects without a previous one")
func noCurrentInputSourceSelectsWithoutPrevious() {
    #expect(
        InputSourceSelectionPolicy.prepare(identifier: "com.apple.keylayout.ABC", current: nil)
            == .select(normalized: "com.apple.keylayout.ABC", previous: nil)
    )
}

@Test("Failed select is not verified and does not restore")
func failedSelectIsFailed() {
    #expect(
        InputSourceSelectionPolicy.afterSelect(
            selectSucceeded: false,
            currentAfter: "com.apple.keylayout.US",
            normalized: "com.apple.keylayout.ABC",
            previous: "com.apple.keylayout.US"
        ) == .failed
    )
}

@Test("Successful select with matching readback is verified")
func matchingReadbackIsVerified() {
    #expect(
        InputSourceSelectionPolicy.afterSelect(
            selectSucceeded: true,
            currentAfter: "com.apple.keylayout.ABC",
            normalized: "com.apple.keylayout.ABC",
            previous: "com.apple.keylayout.US"
        ) == .verified
    )
}

@Test("Successful select with mismatched readback restores the previous Input Source")
func mismatchedReadbackRestoresPrevious() {
    #expect(
        InputSourceSelectionPolicy.afterSelect(
            selectSucceeded: true,
            currentAfter: "com.apple.keylayout.US",
            normalized: "com.apple.keylayout.ABC",
            previous: "com.apple.keylayout.US"
        ) == .restore(previousIdentifier: "com.apple.keylayout.US")
    )
}

@Test("Successful select with mismatched readback and no previous Input Source fails")
func mismatchedReadbackWithoutPreviousIsFailed() {
    #expect(
        InputSourceSelectionPolicy.afterSelect(
            selectSucceeded: true,
            currentAfter: "com.apple.keylayout.US",
            normalized: "com.apple.keylayout.ABC",
            previous: nil
        ) == .failed
    )
}
