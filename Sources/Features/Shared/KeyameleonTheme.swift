import SwiftUI

/// The design tokens the Pencil designs share.
///
/// Colors come from the design's variables and resolve light and dark from the
/// asset catalog. Guided setup and Settings both read from here, so a rebuild
/// never invents a color, radius, or metric of its own.
enum KeyameleonTheme {
    // MARK: Colors

    /// The window behind a flow's content, and the row surface a keyboard group draws on.
    static let windowBackground = Color("OnboardingBackground")
    /// The Settings content pane behind its groups.
    static let contentBackground = Color("KeyameleonContentBackground")
    /// The Settings sidebar the navigation sits on.
    static let sidebarBackground = Color("KeyameleonSidebarBackground")
    /// The card surface for Settings information rows.
    static let cardSurface = Color("KeyameleonCardSurface")
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
        /// The Settings content pane's insets, in the design's order.
        static let panePadding = EdgeInsets(top: 24, leading: 30, bottom: 28, trailing: 30)
        /// Inset group of rows, as the Keyboards list and Guided setup draw it.
        static let groupRadius: CGFloat = 16
        /// Inset group of label and value rows, as About draws it.
        static let informationGroupRadius: CGFloat = 10
        /// The sidebar navigation item and the Input Source picker.
        static let controlRadius: CGFloat = 6
        static let navigationItemHeight: CGFloat = 34
        static let navigationItemSpacing: CGFloat = 4
        static let groupSeparatorInset: CGFloat = 22
    }
}

extension View {
    /// Draws the hairline a Pencil group uses between two rows.
    func keyameleonGroupSeparator(_ isVisible: Bool) -> some View {
        overlay(alignment: .top) {
            if isVisible {
                KeyameleonTheme.border
                    .frame(height: 1)
                    .padding(.leading, KeyameleonTheme.Metrics.groupSeparatorInset)
            }
        }
    }
}
