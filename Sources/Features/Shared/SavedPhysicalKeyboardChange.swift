enum SavedPhysicalKeyboardChange: Equatable {
    case rename(keyboard: PhysicalKeyboard, customName: String?)
    case assign(keyboard: PhysicalKeyboard, assignment: KeyboardAssignment?)
    case replace(old: PhysicalKeyboard, new: PhysicalKeyboard)
    case forget(keyboard: PhysicalKeyboard)
    case designate(SavedManualPhysicalKeyboardDesignation)
}
