import Foundation

/// A collection of fixed size of pre-started, idle worker threads that is ready to execute
/// code asynchronously, executing code concurrently between all threads.
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

    let taskChannels: [TaskChannel]

    let waitGroup: WaitGroup

    let indexer: Locked<Int>

    let onceFlag = OnceState()

    let waitType: WaitType

    static let shared: WorkerPool = WorkerPool(size: ProcessInfo.processInfo.activeProcessorCount)

    /// Initialises an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType = .cancelAll) {
        guard size >= 1 else {
            fatalError("Cannot initialise an instance of WorkerPool with 0 Threads")
        }
        self.waitType = waitType
        waitGroup = WaitGroup()
        taskChannels = (1...size).map { _ in TaskChannel() }
        indexer = Locked(initialValue: 0)
    }

    deinit {
        guard onceFlag.hasExecuted else {
            return
        }
        if case .waitForAll = waitType {
            pollAll()
        }
        taskChannels.forEach { $0.end() }
    }

    /// This enqueues a block of code to be executed by a specific thread in the
    /// ``WorkerPool`` instance
    ///
    /// - Parameters:
    ///   - index: The position of the thread to enqueue the closure
    ///   - body: a non-throwing sendable closure that takes nothing and returns void
    /// - Returns: true if the code was successfully enqueued for execution otherwise false
    public func submitToSpecificThread(at index: Int, _ body: @escaping () -> Void) -> Bool {
        guard (0..<taskChannels.count).contains(index) else {
            return false
        }
        submitTask(at: index, body)
        return true
    }

    func submitTask(at index: Int, _ body: @escaping () -> Void) {
        onceFlag.runOnce {
            taskChannels.forEach { channel in
                Thread { [channel] in
                    while let task = channel.dequeue() { task() }
                }.start()
            }
        }
        taskChannels[index].enqueue(body)
    }

    // Ensures that the index is accessed in a data race free manner
    func currentIndex() -> Int {
        return indexer.updateWhileLocked { index in
            let oldIndex: Int = index
            index = (oldIndex + 1) % taskChannels.count
            return oldIndex
        }
    }
}

extension WorkerPool {

    /// This represents a global multi-threaded pool similar to `DispatchQueue.global()`
    /// as it contains the same number of Threads as the total number of processor count
    public static var globalPool: WorkerPool {
        WorkerPool.shared
    }
}

extension WorkerPool: ThreadPool {

    public func async(_ body: @escaping @Sendable () -> Void) {
        submitTask(at: currentIndex(), body)
    }

    public func submit(_ body: @escaping () -> Void) {
        submitTask(at: currentIndex(), body)
    }

    public func cancel() {
        taskChannels.forEach { $0.clear() }
    }

    public func pollAll() {
        guard onceFlag.hasExecuted else {
            return
        }
        taskChannels.forEach { taskChannel in
            waitGroup.enter()
            taskChannel.enqueue { [waitGroup] in waitGroup.done() }
        }
        waitGroup.waitForAll()
    }
}
