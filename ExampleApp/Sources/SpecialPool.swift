import Foundation
import Primitives

/// Special ThreadPool that uses pthread utilties such as condition and mutex
public final class SpecialThreadPool: ThreadPool {

    private let threadHandles: [UniqueThread]

    private let barrier: PThreadBarrier

    private let onceFlag: OnceState

    private let gen: Locker<RandomGenerator>

    private let wait: WaitType

    public static let globalPool: SpecialThreadPool =
        SpecialThreadPool(
            size: ProcessInfo.processInfo.processorCount, waitType: .waitForAll)!

    public var isBusyExecuting: Bool {
        false
    }

    public func pollAll() {
        threadHandles.forEach { handle in
            handle.submit { [barrier] in
                barrier.arriveAndWait()
            }
        }
        barrier.arriveAndWait()
    }

    public init?(
        size: Int, waitType: WaitType
    ) {
        guard size >= 1 else {
            return nil
        }
        wait = waitType
        barrier = PThreadBarrier(count: UInt32(size + 1))
        onceFlag = OnceState()
        threadHandles = start(size: size)
        gen = Locker(RandomGenerator(to: size))
    }

    public func submit(_ body: @escaping TaskItem) {
        onceFlag.runOnce {
            threadHandles.forEach { $0.start() }
        }
        gen.updateWhileLocked {
            let index = $0.random()
            threadHandles[index].submit(body)
        }
    }

    public func async(_ body: @escaping SendableTaskItem) {
        onceFlag.runOnce {
            threadHandles.forEach { $0.start() }
        }
        gen.updateWhileLocked {
            let index = $0.random()
            threadHandles[index].submit(body)
        }
    }

    public func cancel() {
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

private func start(size: Int) -> [UniqueThread] {
    (0 ..< size).map { _ in
        UniqueThread()
    }
}
