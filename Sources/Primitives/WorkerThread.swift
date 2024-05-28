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

    let handle: Thread

    let taskChannel: UnboundedChannel<QueueOperations>

    let waitType: WaitType

    let barrier: Barrier

    func end() {
        taskChannel.clear()
        taskChannel.close()
        handle.cancel()
    }

    /// Initialises an instance of `WorkerThread` type
    /// - Parameters:
    ///   - waitType: value of `WaitType`
    public init(waitType: WaitType) {
        self.waitType = waitType
        taskChannel = UnboundedChannel()
        barrier = Barrier(size: 2)
        handle = start(channel: taskChannel)
        handle.start()
    }

    public func cancel() {
        taskChannel.clear()
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannel <- .execute(block: body)
    }

    public func async(_ body: @escaping SendableWorkItem) {
        taskChannel <- .execute(block: body)
    }

    public func pollAll() {
        taskChannel <- .wait(with: barrier)
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

extension WorkerThread: CustomStringConvertible {
    public var description: String {
        "Single Thread of \(waitType) type"
    }
}

extension WorkerThread: CustomDebugStringConvertible {

    public var debugDescription: String {
        "Single Thread of \(waitType) type of name: \(handle.name!)"
    }
}

func start(channel: UnboundedChannel<QueueOperations>) -> Thread {
    return Thread {
        while !Thread.current.isCancelled {
            if let operation = channel.dequeue() {
                switch operation {

                case .execute(let block): block()

                case .wait(let barrier): barrier.arriveAndWait()

                }
            }
        }
    }
}
