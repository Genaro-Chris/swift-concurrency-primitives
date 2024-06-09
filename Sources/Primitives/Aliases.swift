/// An executable block of code
public typealias WorkItem = () -> Void

/// An executable block of code which is sendable
public typealias SendableWorkItem = @Sendable () -> Void