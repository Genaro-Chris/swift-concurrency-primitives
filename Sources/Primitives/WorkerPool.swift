import Atomics
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

    enum QueueOperations {

        case ready(WorkItem)
        case wait(Barrier)
    }

    let waitType: WaitType

    let queue: UnboundedChannel<QueueOperations>

    let handles: [NamedThread]

    let barrier: Barrier

    let started: OnceState

    let isBusy: ManagedAtomic<Bool>

    func submitRandomly(_ body: @escaping WorkItem) {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        queue <- .ready(body)
    }

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of WorkerPool with 0 thread")
        }
        self.waitType = waitType
        queue = UnboundedChannel()
        barrier = Barrier(size: size + 1)
        isBusy = ManagedAtomic(false)
        started = OnceState()
        handles = start(queue: queue, size: size, isBusy: isBusy)
    }

    deinit {
        guard started.hasExecuted else { return }
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

    public func async(_ body: @escaping SendableWorkItem) {
        submitRandomly(body)
    }

    public func submit(_ body: @escaping WorkItem) {
        submitRandomly(body)
    }

    public func cancel() {
        guard started.hasExecuted else { return }
        queue.clear()
        queue.close()
        handles.forEach { $0.cancel() }
    }

    public var isBusyExecuting: Bool {
        isBusy.load(ordering: .relaxed)
    }

    public func pollAll() {
        guard started.hasExecuted else { return }
        (0..<handles.count).forEach { _ in
            queue <- .wait(barrier)
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
            " - " + (handle.name!) + "\n"
        }.reduce("") { acc, name in
            return acc + name
        }
        return
            "WorkerPool of \(waitType) type with \(handles.count) thread\(handles.count == 1 ? "" : "s")"
            + ":\n" + threadNames

    }
}

func start(
    queue: UnboundedChannel<WorkerPool.QueueOperations>, size: Int, isBusy: ManagedAtomic<Bool>
) -> [NamedThread] {
    (0..<size).map { index in
        NamedThread("WorkerPool #\(index)") {
            for operation in queue where !Thread.current.isCancelled {
                switch operation {

                case let .ready(work): work()

                case let .wait(barrier): barrier.arriveAndWait()

                }
            }
        }
    }
}
