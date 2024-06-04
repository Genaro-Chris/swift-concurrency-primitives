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

    let barrier: Barrier

    var index: Int

    var currentIndex: Int {
        defer {
            if index == taskChannels.count - 1 {
                index = 0
            } else {
                index += 1
            }
        }
        return index
    }

    /// Initializes an instance of the `WorkerPool` type
    /// - Parameters:
    ///   - size: Number of threads to used in the pool
    ///   - waitType: value of `WaitType`
    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of WorkerPool with 0 Threads")
        }
        self.waitType = waitType
        index =  0
        barrier = Barrier(size: size + 1)
        taskChannels = start(size: size)
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
        taskChannels.end()
    }
}

extension WorkerPool {

    /// This represents a global multi-threaded pool similar to `DispatchQueue.global()`
    /// as it contains the same number of Threads as the total number of processor count
    public static let globalPool = WorkerPool(
        size: ProcessInfo.processInfo.activeProcessorCount, waitType: .waitForAll)
}

extension WorkerPool: ThreadPool {

    public func async(_ body: @escaping SendableWorkItem) {
        taskChannels[currentIndex].enqueue(body)
    }

    public func submit(_ body: @escaping WorkItem) {
        taskChannels[currentIndex].enqueue(body)
    }

    public func cancel() {
        taskChannels.clear()
    }

    public func pollAll() {
        taskChannels.forEach { channel in
            channel.enqueue { [barrier] in barrier.arriveAndWait() }
        }
        barrier.arriveAndWait()
    }
}

func start(size: Int) -> [TaskChannel] {
    (0..<size).map { _ in
        let channel = TaskChannel(size)
        Thread {
            while let operation = channel.dequeue() {
                operation()
            }
        }.start()
        return channel
    }
}


extension Array where Element == TaskChannel {

    func clear() {
        forEach { $0.clear() }
    }

    func end() {
        forEach { $0.end() }
    }
}