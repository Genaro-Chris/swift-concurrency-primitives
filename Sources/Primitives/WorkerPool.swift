import Foundation

/// A collection of fixed size pre-started, idle worker threads that is ready to execute asynchronous
/// code concurrently between all threads.
/// 
/// It uses a random enqueueing strategy that means the thread which the enqueued job will execute
/// is not is known and if a thread is assigned a job then that thread will not be assigned
/// a job until all threads had being jobs
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

    let handles: [WorkerThread]

    let barrier: Barrier

    let started: OnceState

    private func submitRandomly(_ work: @escaping WorkItem) {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        handles.randomElement()?.submit(work)
    }

    /// Submits work to a specific thread in the pool
    /// - Parameters:
    ///   - index: index of the thread which should execute the work
    ///   - work: a non-throwing closure that takes and returns void
    /// - Returns: true if the work was submitted otherwise false
    public func submitToSpecificThread(at index: Int, _ work: @escaping WorkItem) -> Bool {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        guard (0 ..< handles.count).contains(index) else {
            return false
        }
        handles[index].submit(work)
        return true
    }

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    /// - Returns: nil if the size argument is less than one
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            fatalError("Cannot initialize an instance of WorkerPool with 0 thread")
        }
        self.waitType = waitType
        barrier = Barrier(size: size + 1)!
        started = OnceState()
        handles = (0 ..< size).map { index in
            return WorkerThread("WorkerPool #\(index)")
        }
    }

    deinit {
        guard started.hasExecuted else {
            return
        }
        switch waitType {
        case .cancelAll: cancel()

        case .waitForAll:
            pollAll()
            cancel()
        }
    }
}

extension WorkerPool {

    /// This represents a global multithreaded pool similar to `DispatchQueue.global()`
    /// as it contains the same number of threads as the total number of processor count
    public static let globalPool = WorkerPool(
        size: ProcessInfo.processInfo.activeProcessorCount, waitType: .waitForAll)
}

extension WorkerPool: ThreadPool {

    public func async(_ body: @escaping SendableWorkItem) {
        submitRandomly(body)
    }

    public func submit(_ body: @escaping WorkItem) {
        submitRandomly(body)
    }

    public func cancel() {
        guard started.hasExecuted else {
            return
        }
        handles.forEach {
            $0.cancel()
        }
    }

    public var isBusyExecuting: Bool {
        handles.allSatisfy {
            $0.isBusyExecuting
        }
    }

    public func pollAll() {
        guard started.hasExecuted else {
            return
        }
        handles.forEach { [barrier] handle in
            handle.submit {
                barrier.arriveAlone()
            }
        }
        barrier.arriveAndWait()
    }
}

extension WorkerPool: CustomStringConvertible {
    public var description: String {
        "WorkerPool of \(waitType) type with \(handles.count) thread\(handles.count == 1 ? "" : "s")"
    }
}

extension WorkerPool: CustomDebugStringConvertible {
    public var debugDescription: String {
        let threadNames = handles.map { handle in
            " - " + (handle.name ?? "WorkerPool") + "\n"
        }.reduce("") { acc, name in
            return acc + name
        }
        return
            "WorkerPool of \(waitType) type with \(handles.count) thread\(handles.count == 1 ? "" : "s")"
            + ":\n" + threadNames

    }
}
