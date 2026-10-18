#if DEBUG

enum PreviewSetupState: Equatable {
    case permissionRequired
    case permissionDenied
    case assignmentsEmpty
    case assignmentsPopulated
    case pencilAssignments
    case menuAssignments
    case readyEmpty
    case readyPopulated
    case readyPaused
    case persistenceFailure
    case mixedAssignments
    case manyAssignments
    case excludedDevices
    case paused
    case completed
}

#endif
