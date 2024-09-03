/// A synchronization primitive which provides a way to suspend a thread execution
/// in such a way that it consumes no CPU time while waiting for an event to occur.
///
/// It is highly advisable to use this on only one thread to park and on other thread
/// to unpark the previously parked thread
///
/// # Example
/// ```swift
/// let parker = ThreadParker()
/// DispatchQueue.global().async {
///     // perform some work here
///     // unparks the parked thread
///     park.unpark()
/// }
/// // wait for the work to finish before continuing
/// parker.park()
/// // or wait for 3 seconds before continuing
/// park.park(for: .seconds(3))
/// ```
public struct ThreadParker {
    let stageLock: ConditionalLockBuffer<Stage>

    /// Initialise an instance of `WorkerThread` type
    public init() {
        stageLock = ConditionalLockBuffer.create(value: Stage.empty)
    }

    /// Parks the caller thread until the ``unpark`` method is called
    public func park() {
        stageLock.interactWhileLocked { stage, conditionLock in
            // check the state the lock is in right now
            switch stage {
            // park the thread
            case .empty: stage.set(to: .parked)
            // already unparked this thread so just revert state back to empty
            // then return
            case .unparked:
                stage.set(to: .empty)
                return

            case .parked: fatalError("cannot park a thread that is already parked")
            }

            // park this thread until we get a notification
            conditionLock.wait(until: stage == .parked)

            // revert state back to empty so the next time this method is called
            // it can park this callee thread
            stage.set(to: .empty)
        }
    }

    /// Parks the caller thread until the specified time duration passes
    /// - Parameters:
    ///   - for: The time duration to park for
    public func park(for timeout: TimeDuration) {
        stageLock.interactWhileLocked { stage, conditionLock in
            // check the state the lock is in right now
            switch stage {
            // park the thread
            case .empty: stage.set(to: .parked)
            // already unparked this thread so just revert state back to empty
            // then return
            case .unparked:
                stage.set(to: .empty)
                return

            case .parked: fatalError("cannot park a thread that is already parked")
            }

            // park this thread for the time until we get a notification
            // or just wakeup after the time duration passes
            conditionLock.wait(timeout: timeout)

            // revert state back to empty so the next time this method is called
            // it can park this callee thread
            stage.set(to: .empty)
        }
    }

    /// Unparks the parked thread
    public func unpark() {
        stageLock.interactWhileLocked { stage, conditionLock in
            // check if the stage is parked already otherwise do nothing
            if case Stage.parked = stage {
                // send notification
                stage.set(to: .unparked)
            }
            // unpark the parked thread
            conditionLock.signal()
        }
    }
}

enum Stage {
    case empty
    case unparked
    case parked

    mutating func set(to stage: Stage) {
        self = stage
    }
}
