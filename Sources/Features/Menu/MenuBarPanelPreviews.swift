#if DEBUG
import SwiftUI

#Preview("Panel ready") {
    let fixture = PreviewFixtures.setup(.assignmentsPopulated)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel empty") {
    let fixture = PreviewFixtures.setup(.assignmentsEmpty)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
}

#Preview("Panel paused") {
    let fixture = PreviewFixtures.setup(.paused)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.dark)
}

#Preview("Panel unavailable assignment") {
    let fixture = PreviewFixtures.setup(.mixedAssignments)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
}

#Preview("Panel overflow") {
    let fixture = PreviewFixtures.setup(.manyAssignments)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
