import SwiftUI

/// One line explaining the selected External Change Response.
@MainActor
struct ExternalChangeResponseFooter: View {
    let response: ExternalChangeResponse

    var body: some View {
        Text(explanation)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    VStack(alignment: .leading) {
        ForEach(ExternalChangeResponse.allCases, id: \.self) { response in
            ExternalChangeResponseFooter(response: response)
        }
    }
    .padding()
    .frame(width: 420, alignment: .leading)
    .background(Theme.contentBackground)
}
#endif
