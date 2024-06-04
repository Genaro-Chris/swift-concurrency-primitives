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
/// let threadHandle = WorkerThread(name: "Thread", waitType: .canncelAll)
/// for index in 1 ... 10 {
///    threadHandle.submit {
///         // some heavy CPU bound work
///    }
/// }
/// ```
public final class WorkerThread: ThreadPool {

    let taskChannel: TaskChannel

    let waitType: WaitType

    let barrier: Barrier


    func end() {
        taskChannel.end()
    }

    /// Initialises an instance of `WorkerThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType) {
        self.waitType = waitType
        taskChannel = TaskChannel()
        barrier = Barrier(size: 2)
        start(channel: taskChannel).start()
    }

    public func cancel() {
        taskChannel.clear()
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannel.enqueue(body)
    }

    public func async(_ body: @escaping SendableWorkItem) {
        taskChannel.enqueue(body)
    }

    public func pollAll() {
        taskChannel.enqueue { [barrier] in barrier.arriveAndWait() }
        barrier.arriveAndWait()
    }

    deinit {
        switch waitType {
        case .cancelAll: end()

        case .waitForAll:
            pollAll()
            end()
        }
    }
}

func start(channel: TaskChannel) -> Thread {
    return Thread {
        while let operation = channel.dequeue() {
            operation()
        }
    }
}
