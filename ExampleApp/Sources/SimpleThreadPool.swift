import Foundation
@_spi(ThreadSync) import Primitives

/// Simple Implementation of the `ThreadPool` type
public final class SimpleThreadPool {

    let waitType: WaitType

    let handles: [NamedThread]

    let barrier: Barrier

    let started: OnceState

    private func end() {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        handles.forEach { $0.cancel() }
    }

    private func submitRandomly(_ body: @escaping WorkItem) {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        handles.randomElement()?.submit(body)
    }

    public func submitToSpecificThread(at index: Int, _ body: @escaping WorkItem) -> Bool {
        guard (0..<handles.count).contains(index) else {
            return false
        }
        started.runOnce {
            handles.forEach { $0.start() }
        }
        handles[index].submit(body)
        return true
    }

    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of SimpleThreadPool with 0 thread")
        }
        self.waitType = waitType
        barrier = Barrier(size: size + 1)
        started = OnceState()
        handles = (0..<size).map { index in
            return NamedThread("SimpleThreadPool #\(index)")
        }
    }

    deinit {
        guard started.hasExecuted else {
            return
        }
        switch waitType {
        case .cancelAll: end()

        case .waitForAll:
            pollAll()
            end()
        }
        handles.forEach { $0.join() }
    }
}

extension SimpleThreadPool {

    public static let globalPool = SimpleThreadPool(
        size: ProcessInfo.processInfo.activeProcessorCount, waitType: .waitForAll)
}

extension SimpleThreadPool: ThreadPool {

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
            $0.clear()
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
