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
/// let threadHandle = SingleThread(name: "Thread", waitType: .canncelAll)
/// for index in 1 ... 10 {
///    threadHandle.submit {
///         // some heavy CPU bound work
///    }
/// }
/// ```
public final class SingleThread: ThreadPool {

    private let handle: WorkerThread

    private let waitType: WaitType

    private let barrier: Barrier

    private let started: OnceState

    /// Initialises an instance of `SingleThread` type
    /// - Parameters:
    ///   - name: name to assign as the thread name, which defaults to `SingleThread`
    ///   - waitType: value of `WaitType`
    public init(name: String = "SingleThread", waitType: WaitType) {
        handle = WorkerThread(name)
        self.waitType = waitType
        barrier = Barrier(size: 2)!
        started = OnceState()
    }

    public func cancel() {
        handle.cancel()
    }

    public func submit(_ body: @escaping WorkItem) {
        started.runOnce {
            handle.start()
        }
        handle.submit(body)
    }

    public func async(_ body: @escaping SendableWorkItem) {
        submit(body)
    }

    public var isBusyExecuting: Bool {
        handle.isBusyExecuting
    }

    public func pollAll() {
        guard !handle.isEmpty && !isBusyExecuting else {
            return
        }
        handle.submit { [barrier] in barrier.arriveAlone() }
        barrier.arriveAndWait()
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

extension SingleThread: CustomStringConvertible {
    public var description: String {
        "Single Thread of \(waitType) type"
    }
}

extension SingleThread: CustomDebugStringConvertible {

    public var debugDescription: String {
        "Single Thread of \(waitType) type of name: \(handle.name!)"
    }
}
