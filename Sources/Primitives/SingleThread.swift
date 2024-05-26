import Foundation

/// A special kind of concurrency primitive construct that allows one to submit tasks
/// to be executed on a separate thread.
///
/// This is particularly useful for dispatching heavy workload off the current thread.
///
/// It is very similar to swift [DispatchSerialQueue](https://developer.apple.com/documentation/dispatch/dispatchserialqueue)
///
/// Example
/// ```swift
/// let threadHandle = SingleThread(name: "Thread", waitType: .canncelAll)
/// for index in 1 ... 10 {
///    threadHandle.submit {
///         // some heavy CPU bound work
///    }
/// }
/// ```
public final class SingleThread: ThreadPool {

    let handle: Thread

    let queue: UnboundedChannel<QueueOperations>

    let waitType: WaitType

    let barrier: Barrier

    let started: OnceState

    func end() {
        handle.cancel()
    }

    /// Initialises an instance of `SingleThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType) {
        self.waitType = waitType
        queue = UnboundedChannel()
        barrier = Barrier(size: 2)
        started = OnceState()
        handle = start(queue: queue)
    }

    public func cancel() {
        guard started.hasExecuted else { return }
        queue.clear()
    }

    public func submit(_ body: @escaping WorkItem) {
        started.runOnce {
            handle.start()
        }
        queue <- .ready(body)
    }

    public func async(_ body: @escaping SendableWorkItem) {
        submit(body)
    }

    public func pollAll() {
        guard started.hasExecuted else { return }
        queue <- .wait(barrier)
        barrier.arriveAndWait()
    }

    deinit {
        guard started.hasExecuted else { return }
        switch waitType {
        case .cancelAll: end()

        case .waitForAll:
            pollAll()
            end()
        }
    }
}

extension SingleThread: CustomStringConvertible {
    public var description: String {
        "Single Thread of \(waitType) type"
    }
}

extension SingleThread: CustomDebugStringConvertible {

    public var debugDescription: String {
        "Single Thread of \(waitType) type of name: \(handle.name!)"
    }
}

private func start(
    queue: UnboundedChannel<QueueOperations>
) -> Thread {
    return Thread {
        while !Thread.current.isCancelled {
            while let operation = queue.dequeue() {
                switch operation {

                case let .ready(work): work()

                case let .wait(barrier): barrier.arriveAndWait()

                }
            }

        }
    }
}
