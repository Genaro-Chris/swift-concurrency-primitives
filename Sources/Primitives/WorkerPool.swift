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

    final class Buffer {

        let mutex: Mutex

        let condition: Condition

        var buffer: ContiguousArray<WorkItem>

        init() {
            buffer = ContiguousArray()
            mutex = Mutex()
            condition = Condition()
        }

        func enqueue(_ item: @escaping WorkItem) {
            mutex.whileLocked {
                buffer.append(item)
                condition.signal()
            }
        }

        func dequeue() -> WorkItem? {
            mutex.whileLocked {
                condition.wait(mutex: mutex, condition: !buffer.isEmpty)
                guard !buffer.isEmpty else { return nil }
                return buffer.removeFirst()
            }
        }

        func clear() {
            mutex.whileLocked {
                buffer.removeAll()
            }
        }
    }

    let waitType: WaitType

    let buffer: Buffer

    let handles: [Thread]

    let barrier: Barrier

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of WorkerPool with 0 thread")
        }
        self.waitType = waitType
        buffer = Buffer()
        barrier = Barrier(size: size + 1)
        handles = start(buffer: buffer, size: size)
        handles.forEach { $0.start() }
    }

    deinit {
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
        buffer.enqueue(body)
    }

    public func submit(_ body: @escaping WorkItem) {
        buffer.enqueue(body)
    }

    public func cancel() {
        buffer.clear()
    }

    public func pollAll() {
        (0..<handles.count).forEach { _ in
            buffer.enqueue { [barrier] in barrier.arriveAndWait() }
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

private func start(
    buffer: WorkerPool.Buffer, size: Int
) -> [Thread] {
    (0..<size).map { _ in
        return Thread {
            while !Thread.current.isCancelled {
                buffer.dequeue()?()
            }
        }
    }
}
