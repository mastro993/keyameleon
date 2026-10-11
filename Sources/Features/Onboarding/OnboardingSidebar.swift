import AppKit
import SwiftUI

@MainActor
struct OnboardingSidebar: View {
    let step: GuidedSetupStep
    let hasAssignments: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text(AppIdentity.current.name)
                    .font(.title2.weight(.semibold))
            }
            .padding(.top, 52)

            Text(headline)
                .padding(.top, 92)
                .font(.largeTitle)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
            Image(artwork)
                .resizable()
                .scaledToFit()
                .frame(width: 227)
                .padding(.top, 28)
            Spacer(minLength: 35)
            Text(footer)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 30)
                .padding(.bottom, 34)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 34)
        .frame(width: 295)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background {
            Image("OnboardingSidebar")
                .resizable()
                .scaledToFill()
                .frame(width: 295)
                .clipped()
                .overlay(.black.opacity(colorScheme == .dark ? 0.6 : 0.25))
        }
        .accessibilityElement(children: .contain)
    }

    private var headline: LocalizedStringResource {
        switch step {
        case .permission: .tagline
        case .assignments: .setupHeadlineAssignments
        case .ready: .setupHeadlineReady
        }
    }

    private var artwork: String {
        switch step {
        case .permission: "OnboardingPermissions"
        case .assignments: "OnboardingKeyboards"
        case .ready: "OnboardingReady"
        }
    }

    private var footer: LocalizedStringResource {
        switch step {
        case .permission: .setupFooterPermission
        case .assignments: .setupFooterAssignments
        case .ready: hasAssignments ? .setupFooterReadyAssigned : .setupFooterReadyUnassigned
        }
    }
}

#if DEBUG
#Preview("Onboarding sidebar") {
    OnboardingSidebar(step: .permission, hasAssignments: false)
        .frame(height: 750)
}
#endif
