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

    let taskChannel: UnboundedChannel<WorkItem>

    let handles: [Thread]

    let barrier: Barrier

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of WorkerPool with 0 threads")
        }
        self.waitType = waitType
        taskChannel = UnboundedChannel()
        barrier = Barrier(size: size + 1)
        handles = start(channel: taskChannel, size: size)
        handles.forEach { $0.start() }
    }

    deinit {
        switch waitType {
        case .cancelAll: end()

        case .waitForAll:
            pollAll()
            end()
        }

    }

    func end() {
        taskChannel.clear()
        taskChannel.close()
        handles.forEach { $0.cancel() }
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
        taskChannel <- body
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannel <- body
    }

    public func cancel() {
        taskChannel.clear()
    }

    public func pollAll() {
        (0..<handles.count).forEach { _ in
            taskChannel <- { [barrier] in barrier.arriveAndWait() }
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

func start(channel: UnboundedChannel<WorkItem>, size: Int) -> [Thread] {
    (0..<size).map { _ in
        return Thread {
            while !Thread.current.isCancelled {
                channel.dequeue()?()
            }
        }
    }
}
