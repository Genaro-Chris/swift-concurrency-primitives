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
public final class WorkerThread {

    let taskChannel: TaskChannel

    let waitgroup: WaitGroup

    let waitType: WaitType

    /// Initialises an instance of `WorkerThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType) {
        self.waitType = waitType
        taskChannel = TaskChannel()
        waitgroup = WaitGroup()
        start(channel: taskChannel)
    }

    deinit {
        if case .waitForAll = waitType {
            pollAll()
        }
        taskChannel.end()
    }

}

extension WorkerThread: ThreadPool {

    public func cancel() {
        taskChannel.clear()
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannel.enqueue(body)
    }

    public func async(_ body: @escaping @Sendable () -> Void) {
        taskChannel.enqueue(body)
    }

    public func pollAll() {
        waitgroup.enter()
        taskChannel.enqueue { [waitgroup] in waitgroup.done() }
        waitgroup.waitForAll()
    }
}

func start(channel: TaskChannel) {
    Thread { [channel] in
        while let task = channel.dequeue() { task() }
    }.start()
}
