import Atomics
import Foundation
@_spi(ThreadSync) import Primitives

/// Simple Implementation of the `ThreadPool` type
public final class SimpleThreadPool: ThreadPool {

    private let queue: any Channel<() -> Void>

    private let threadHandles: [NamedThread]

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
        threadHandles = start(queue: queue, size: size, barrier: barrier)
    }

    public func submit(_ body: @escaping () -> Void) {
        onceFlag.runOnce {
            threadHandles.forEach { $0.start() }
        }
        queue <- body
    }

    public func async(_ body: @escaping @Sendable () -> Void) {
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
    queue: some Channel<() -> Void>, size: Int, barrier: Barrier
) -> [NamedThread] {
    (0 ..< size).map { index in
        NamedThread(name: "SimpleThreadPool #\(index)") {
            repeat {
                if let operation = queue.dequeue() {
                    operation()
                }
            } while !Thread.current.isCancelled
        }
    }
}

extension SimpleThreadPool: CustomStringConvertible {
    public var description: String {
        "SimpleThreadPool of \(wait) type with \(threadHandles.count) thread\(threadHandles.count == 1 ? "" : "s")"
    }
}

extension SimpleThreadPool: CustomDebugStringConvertible {
    public var debugDescription: String {
        let threadNames = threadHandles.map { handle in
            " - " + (handle.name ?? "SimpleThreadPool") + "\n"
        }.reduce("") { acc, name in
            return acc + name
        }
        return
            "SimpleThreadPool of \(wait) type with \(threadHandles.count) thread\(threadHandles.count == 1 ? "" : "s")"
            + ":\n" + threadNames

    }
}

extension SimpleThreadPool: Sendable {}

final class NamedThread: Thread {

    let threadName: String

    let block: () -> Void

    override var name: String? {
        get { threadName }
        set {}
    }

    init(name: String, _ block: @escaping () -> Void) {
        threadName = name
        self.block = block
        super.init()
    }

    override func main() {
        block()
    }
}

extension NamedThread: @unchecked Sendable {}
