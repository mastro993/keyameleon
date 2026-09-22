#if DEBUG
import SwiftUI

#Preview("Panel ready") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    KeyameleonMenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: KeyameleonPreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel empty") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsEmpty)
    KeyameleonMenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: KeyameleonPreviewFixtures.panelActions()
    )
}

#Preview("Panel paused") {
    let fixture = KeyameleonPreviewFixtures.setup(.paused)
    KeyameleonMenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: KeyameleonPreviewFixtures.panelActions()
    )
    .preferredColorScheme(.dark)
}

#Preview("Panel unavailable assignment") {
    let fixture = KeyameleonPreviewFixtures.setup(.mixedAssignments)
    KeyameleonMenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: KeyameleonPreviewFixtures.panelActions()
    )
}

#Preview("Panel overflow") {
    let fixture = KeyameleonPreviewFixtures.setup(.manyAssignments)
    KeyameleonMenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: KeyameleonPreviewFixtures.panelActions()
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
