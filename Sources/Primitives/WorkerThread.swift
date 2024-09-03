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

    let onceFlag: OnceState

    /// Initialises an instance of `WorkerThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType = .cancelAll) {
        self.waitType = waitType
        taskChannel = TaskChannel()
        waitgroup = WaitGroup()
        onceFlag = OnceState()
    }

    deinit {
        guard onceFlag.hasExecuted else {
            return
        }
        if case .waitForAll = waitType {
            pollAll()
        }
        taskChannel.end()
    }

    func submitTask(_ body: @escaping () -> Void) {
        onceFlag.runOnce {
            Thread { [taskChannel] in
                while let task = taskChannel.dequeue() { task() }
            }.start()
        }
        taskChannel.enqueue(body)
    }

}

extension WorkerThread: ThreadPool {

    public func cancel() {
        taskChannel.clear()
    }

    public func submit(_ body: @escaping () -> Void) {
        submitTask(body)
    }

    public func async(_ body: @escaping @Sendable () -> Void) {
        submitTask(body)
    }

    public func pollAll() {
        guard onceFlag.hasExecuted else {
            return
        }
        waitgroup.enter()
        taskChannel.enqueue { [waitgroup] in waitgroup.done() }
        waitgroup.waitForAll()
    }
}
