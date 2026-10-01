enum SavedPhysicalKeyboardChangeResult: Equatable {
    case committed(SavedPhysicalKeyboardChange)
    case failed
    case blocked
    case nothingPending
}
