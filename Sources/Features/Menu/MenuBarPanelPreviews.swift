#if DEBUG
import SwiftUI

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
    .padding(.horizontal, Theme.Menu.listInset)
    .padding(.vertical, Theme.Menu.sectionInset)
    .frame(width: MenuBarPanelContent.panelWidth)
}
#endif
