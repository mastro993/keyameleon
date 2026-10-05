import SwiftUI

/// The design tokens the Pencil designs share.
///
/// Colors come from the design's variables and resolve light and dark from the
/// asset catalog. Guided setup and Settings both read from here, so a rebuild
/// never invents a color, radius, or metric of its own.
enum Theme {
    // MARK: Colors

    /// The window behind a flow's content, and the row surface a keyboard group draws on.
    static let windowBackground = Color("OnboardingBackground")
    /// The Settings content pane behind its groups.
    static let contentBackground = Color("ContentBackground")
    /// The Settings sidebar the navigation sits on.
    static let sidebarBackground = Color("SidebarBackground")
    /// The card surface for Settings information rows.
    static let cardSurface = Color("CardSurface")
    /// The softer surface Guided setup uses behind requirement and preview blocks.
    static let surface = Color("OnboardingSurface")
    static let primary = Color("OnboardingPrimary")
    static let secondary = Color("OnboardingSecondary")
    static let muted = Color("OnboardingMuted")
    static let border = Color("OnboardingBorder")
    static let chip = Color("OnboardingChip")
    static let accent = Color("OnboardingAccent")
    static let button = Color("OnboardingButton")
    static let success = Color("OnboardingSuccess")
    static let successText = Color("OnboardingSuccessText")
    static let textOnAccent = Color.white

    // MARK: Metrics

    enum Metrics {
        /// The smallest Settings window the Pencil design allows.
        static let settingsWindowMinimumWidth: CGFloat = 840
        static let settingsWindowMinimumHeight: CGFloat = 560
        static let sidebarWidth: CGFloat = 220
        /// The sidebar's top inset, measured from the bottom of the native title bar.
        static let sidebarTopInset: CGFloat = 24
        /// The Settings content pane's insets, and the spacing between its blocks.
        static let panePadding = EdgeInsets(top: 24, leading: 30, bottom: 24, trailing: 30)
        static let paneSpacing: CGFloat = 20
        /// Inset group of rows, as the Keyboards list and Guided setup draw it.
        static let groupRadius: CGFloat = 16
        /// Inset group of label and value rows, as About draws it.
        static let informationGroupRadius: CGFloat = 10
        /// The sidebar navigation item and the Input Source picker.
        static let controlRadius: CGFloat = 6
        static let navigationItemHeight: CGFloat = 34
        static let navigationItemSpacing: CGFloat = 4
        /// Settings rows sit in a tighter group than Guided setup's rows.
        static let settingsKeyboardRowPadding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        static let onboardingKeyboardRowPadding = EdgeInsets(top: 18, leading: 22, bottom: 18, trailing: 22)
        /// The horizontal inset every Settings information row takes, and its design height.
        static let informationRowInset: CGFloat = 16
        static let informationRowMinHeight: CGFloat = 39
    }
}

extension View {
    /// Draws the hairline a Pencil group uses between two rows, inset like the rows it separates.
    func keyameleonGroupSeparator(_ isVisible: Bool, inset: CGFloat) -> some View {
        overlay(alignment: .top) {
            if isVisible {
                Theme.border
                    .frame(height: 1)
                    .padding(.leading, inset)
            }
        }
    }
}
