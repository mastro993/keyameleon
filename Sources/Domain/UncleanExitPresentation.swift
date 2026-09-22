/// Launch decision for the pending Unclean Exit notice.
///
/// The notice earns a window only when the previous process left the notice
/// pending, this launch starts the application surface, and Guided setup has
/// finished. Hosted unit tests and the Guided setup launch path stay windowless.
enum UncleanExitPresentation {
    static func shouldOpenAbout(
        hasPendingNotice: Bool,
        startsApplicationSurface: Bool,
        setupComplete: Bool
    ) -> Bool {
        hasPendingNotice && startsApplicationSurface && setupComplete
    }
}
