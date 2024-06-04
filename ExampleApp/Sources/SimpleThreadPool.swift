import Foundation
@_spi(ThreadSync) import Primitives

/// Simple Implementation of the `ThreadPool` type
public final class SimpleThreadPool {

    let waitType: WaitType

    let taskChannel: UnboundedChannel<WorkItem>

    let handles: [NamedThread]

    let barrier: Barrier

    let started: OnceState

    private func end() {
        guard started.hasExecuted else { return }
        taskChannel.close()
        taskChannel.clear()
        handles.forEach { $0.cancel() }
    }

    private func submitRandomly(_ body: @escaping WorkItem) {
        started.runOnce {
            handles.forEach { $0.start() }
        }
        taskChannel <- body
    }

    public init(size: Int, waitType: WaitType) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize an instance of SimpleThreadPool with 0 thread")
        }
        self.waitType = waitType
        barrier = Barrier(size: size + 1)
        started = OnceState()
        let taskChannel = UnboundedChannel<WorkItem>()
        handles = (0..<size).map { index in
            return NamedThread("SimpleThreadPool #\(index)", queue: taskChannel)
        }
        self.taskChannel = taskChannel
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
        taskChannel.clear()
    }

    public func pollAll() {
        guard started.hasExecuted else {
            return
        }
        (0..<handles.count).forEach { [barrier] _ in
            taskChannel <- {
                barrier.arriveAlone()
            }
        }
        barrier.arriveAndWait()
    }
}
