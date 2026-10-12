enum SavedPhysicalKeyboardChange: Equatable {
    case rename(keyboard: PhysicalKeyboard, customName: String?)
    case assign(keyboard: PhysicalKeyboard, assignment: KeyboardAssignment?)
}
