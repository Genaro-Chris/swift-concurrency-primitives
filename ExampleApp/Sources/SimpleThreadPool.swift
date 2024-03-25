import Atomics
import Foundation
@_spi(ThreadSync) import Primitives

/// Simple Implementation of the `ThreadPool` type
public final class SimpleThreadPool: ThreadPool {

    private let queue: any Channel<TaskItem>

    private let threadHandles: [UnnamedThread]

    private let barrier: Barrier

    private let onceFlag: OnceState

    private let wait: WaitType

    public static let globalPool: SimpleThreadPool =
        SimpleThreadPool(
            size: ProcessInfo.processInfo.processorCount, waitType: .waitForAll)!

    public var isBusyExecuting: Bool {
       false
    }

    public func pollAll() {
        (0 ..< threadHandles.count).forEach { _ in
            queue <- { [barrier] in
                barrier.decrementAndWait()
            }
        }
        barrier.decrementAndWait()
    }

    public init?(
        size: Int, waitType: WaitType
    ) {
        guard size >= 1 else {
            return nil
        }
        wait = waitType
        queue = UnboundedChannel()
        barrier = Barrier(size: size + 1)!
        onceFlag = OnceState()
        threadHandles = start(queue: queue, size: size)
    }

    public func submit(_ body: @escaping TaskItem) {
        onceFlag.runOnce {
            threadHandles.forEach { $0.start() }
        }
        queue <- body
    }

    public func async(_ body: @escaping SendableTaskItem) {
        onceFlag.runOnce {
            threadHandles.forEach { $0.start() }
        }
        queue <- body
    }

    public func cancel() {
        queue.close()
        threadHandles.forEach { $0.cancel() }
    }

    deinit {
        switch wait {
        case .cancelAll:
            cancel()
        case .waitForAll:
            pollAll()
            cancel()
        }
    }
}

private func start(
    queue: some Channel<TaskItem>, size: Int
) -> [UnnamedThread] {
    (0 ..< size).map { _ in
        UnnamedThread {
            repeat {
                if let operation = queue.dequeue() {
                    operation()
                }
            } while !Thread.current.isCancelled
        }
    }
}
