#if DEBUG
import SwiftUI

#Preview("Panel ready light") {
    let fixture = PreviewFixtures.setup(.menuAssignments, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel ready dark") {
    let fixture = PreviewFixtures.setup(.menuAssignments, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.dark)
}

#Preview("Panel paused light") {
    let fixture = PreviewFixtures.setup(.menuAssignments, menuCompleted: true, menuPaused: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel paused dark") {
    let fixture = PreviewFixtures.setup(.menuAssignments, menuCompleted: true, menuPaused: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.dark)
}

#Preview("Panel permission") {
    let fixture = PreviewFixtures.setup(.permissionRequired, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel empty") {
    let fixture = PreviewFixtures.setup(.assignmentsEmpty, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel unavailable assignment") {
    let fixture = PreviewFixtures.setup(.mixedAssignments, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.light)
}

#Preview("Panel overflow") {
    let fixture = PreviewFixtures.setup(.manyAssignments, menuCompleted: true)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Panel assignments increased contrast") {
    let fixture = PreviewFixtures.setup(.menuAssignments, menuCompleted: true)
    let sources = Dictionary(uniqueKeysWithValues: fixture.model.physicalKeyboards.compactMap { keyboard in
        fixture.model.assignedInputSource(for: keyboard).map { (keyboard.id, $0) }
    })
    MenuBarAssignmentSection(
        list: MenuBarAssignmentList(
            physicalKeyboards: fixture.model.physicalKeyboards,
            assignedInputSources: sources
        ),
        emphasis: .highContrast
    )
    .padding(.horizontal, Theme.Menu.outerInset)
    .padding(.vertical, Theme.Menu.sectionInset)
    .frame(width: MenuBarPanelContent.panelWidth)
}
#endif
