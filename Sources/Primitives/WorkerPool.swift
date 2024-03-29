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

    let notifier: Notifier

    let lock: Lock

    let started: OnceState

    private func submitRandomly(_ work: @escaping () -> Void) {
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
    @discardableResult
    public func submitToSpecificThread(at index: Int, _ work: @escaping () -> Void) -> Bool {
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
        handles = (0 ..< size).map { index in
            return WorkerThread("Thread #\(index)")
        }
        notifier = Notifier(size: size)!
        lock = Lock()
        started = OnceState()
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
        handles.forEach { $0.join() }
    }
}

extension WorkerPool {

    /// This represents a global multithreaded pool similar to `DispatchQueue.global()`
    /// as it contains the same number of threads as the total number of processor count
    public static let globalPool = WorkerPool(
        size: ProcessInfo.processInfo.activeProcessorCount, waitType: .waitForAll)
}

extension WorkerPool: ThreadPool {

    public func async(_ body: @escaping @Sendable () -> Void) {
        submitRandomly(body)
    }

    public func submit(_ body: @escaping () -> Void) {
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
        guard !handles.allSatisfy({ !$0.isBusyExecuting && $0.isEmpty }) else {
            return
        }
        handles.forEach { [notifier] handle in
            handle.submit {
                notifier.notify()
            }
        }
        notifier.waitForAll()
    }
}

extension WorkerPool: CustomStringConvertible {
    public var description: String {
        "ThreadPool of \(waitType) type with \(handles.count) thread\(handles.count == 1 ? "" : "s")"
    }
}

extension WorkerPool: CustomDebugStringConvertible {
    public var debugDescription: String {
        let threadNames = handles.map { handle in
            " - " + (handle.name ?? "ThreadPool") + "\n"
        }.reduce("") { acc, name in
            return acc + name
        }
        return
            "ThreadPool of \(waitType) type with \(handles.count) thread\(handles.count == 1 ? "" : "s")"
            + ":\n" + threadNames

    }
}
