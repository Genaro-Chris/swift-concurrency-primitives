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

    let waitgroup: WaitGroup

    func end() {
        taskChannel.end()
    }

    /// Initialises an instance of `WorkerThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType) {
        self.waitType = waitType
        taskChannel = TaskChannel()
        waitgroup = WaitGroup()
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

    @available(
        *, noasync,
        message:
            "This function blocks the calling thread and therefore shouldn't be called from an async context"
    )
    public func pollAll() {
        waitgroup.enter()
        taskChannel.enqueue { [waitgroup] in waitgroup.done() }
        waitgroup.waitForAll()
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
        while let task = channel.dequeue() { task() }
    }
}
