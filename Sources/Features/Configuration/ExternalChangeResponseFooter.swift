import SwiftUI

/// One line explaining the selected External Change Response.
@MainActor
struct ExternalChangeResponseFooter: View {
    let response: ExternalChangeResponse

    var body: some View {
        Text(explanation)
    }

    private var explanation: String {
        switch response {
        case .switchBack:
            "The next key press switches to the input source assigned to that keyboard."
        case .holdUntilMatch:
            "The new input source stays until you type on a keyboard assigned to it."
        case .holdUntilKeyboardChange:
            "The new input source stays until you type on another keyboard."
        }
    }
}

#if DEBUG
#Preview("External Change Response footer") {
    Form {
        ForEach(ExternalChangeResponse.allCases, id: \.self) { response in
            Section {
                Text(response.rawValue)
            } footer: {
                ExternalChangeResponseFooter(response: response)
            }
        }
    }
    .formStyle(.grouped)
    .frame(width: 520)
}
#endif
