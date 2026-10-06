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

    enum Menu {
        static let accent = Color.accentColor
        static let activeFill = Color.accentColor.opacity(0.18)
        static let width: CGFloat = 320
        /// One assignment pill, and the unit five visible rows scroll against.
        static let rowHeight: CGFloat = 34
        static let rowSpacing: CGFloat = 2
        static let sectionInset: CGFloat = 6
        /// The horizontal inset the assignment list keeps from the panel edges.
        static let listInset: CGFloat = 8
        static let rowRadius: CGFloat = 12
        static let rowInset: CGFloat = 8
        static let rowGap: CGFloat = 14
        static let statusSize: CGFloat = 14
        static let badgeWidth: CGFloat = 24
        static let badgeHeight: CGFloat = 16
        static let badgeRadius: CGFloat = 4
        static let badgeInset: CGFloat = 4
        /// The single opacity layer a disconnected pill's mark, title, and badge take.
        static let disconnectedOpacity: Double = 0.45
        static let highContrastDisconnectedOpacity: Double = 0.8
    }

    // MARK: Typography

    /// The design's type roles, spelled with the semantic styles their sizes match.
    enum Typography {
        /// `type-headline`, medium: a pane's section title.
        static let sectionTitle = Font.body.weight(.medium)
        /// `type-body`, regular.
        static let body = Font.body
        /// `type-body`, medium: a row title such as a Physical Keyboard Name.
        static let rowTitle = Font.body.weight(.medium)
        /// `type-body`, medium: the selected sidebar item.
        static let navigationLabelSelected = Font.body.weight(.medium)
        /// `type-body`, semibold: the sidebar mark and other emphasised body text.
        static let bodyStrong = Font.body.weight(.semibold)
        /// `type-callout`, regular: explanations, help, and credits.
        static let caption = Font.callout
        /// `type-subheadline`, regular: connection status and folder paths.
        static let subheadline = Font.subheadline
        /// `type-title-2`, medium: the About app name.
        static let screenTitle = Font.title2.weight(.medium)
        /// `type-title-2`, semibold: a pane's empty state title.
        static let emptyStateTitle = Font.title2.weight(.semibold)
        /// Chip and badge labels.
        static let chip = Font.caption2.weight(.bold)
    }

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
