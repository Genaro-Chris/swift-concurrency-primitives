import Foundation

/// A collection of fixed size of pre-started, idle worker threads that is ready to execute asynchronous
/// code concurrently between all threads.
///
/// It is very similar to Swift's [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
///
/// Example
/// ```swift
/// let pool = WorkerPool(size: 4, waitType: .waitForAll)!
/// for index in 1 ... 10 {
///    pool.submit {
///         // some heavy CPU bound work
///    }
/// }
/// ```
public final class WorkerPool {

    let waitType: WaitType

    let taskChannels: [TaskChannel]

    let waitGroup: WaitGroup

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of WorkerPool with 0 Threads")
        }
        self.waitType = waitType
        waitGroup = WaitGroup()
        taskChannels = start(size: size)
    }

    /// This enqueues a block of code to be executed by a thread
    /// - Parameters:
    ///   - index: The position of the thread to enqueue the closure
    ///   - body: a non-throwing sendable closure that takes and returns void
    /// - Returns: true if the code was successfully enqueued for execution otherwise false
    public func submitToSpecificThread(at index: Int, _ body: @escaping WorkItem) -> Bool {
        guard (0..<taskChannels.count).contains(index) else {
            return false
        }
        taskChannels[index].enqueue(body)
        return true
    }

    deinit {
        if case .waitForAll = waitType {
            pollAll()
        }
        end()
    }

    func end() {
        taskChannels.forEach { $0.end() }
    }
}

extension WorkerPool {

    /// This represents a global multi-threaded pool similar to `DispatchQueue.global()`
    /// as it contains the same number of Threads as the total number of processor count
    public static let globalPool: WorkerPool = WorkerPool(
        size: ProcessInfo.processInfo.activeProcessorCount, waitType: .waitForAll)
}

extension WorkerPool: ThreadPool {

    public func async(_ body: @escaping SendableWorkItem) {
        taskChannels.randomElement()?.enqueue(body)
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannels.randomElement()?.enqueue(body)
    }

    public func cancel() {
        taskChannels.forEach { $0.clear() }
    }

    #if compiler(>=5.7) || swift(>=5.7)
        @available(
            *, noasync,
            message:
                "This function blocks the calling thread and therefore shouldn't be called from an async context"
        )
    #endif
    public func pollAll() {
        taskChannels.forEach { taskChannel in
            waitGroup.enter()
            taskChannel.enqueue { [waitGroup] in waitGroup.done() }
        }
        waitGroup.waitForAll()
    }
}

func start(size: Int) -> [TaskChannel] {
    (0..<size).map { _ in
        let channel: TaskChannel = TaskChannel(size)
        Thread {
            while let ops = channel.dequeue() { ops() }
        }.start()
        return channel
    }
}
