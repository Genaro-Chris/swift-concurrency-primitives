import Foundation
import Primitives

/// The class enqueueing jobs onto the `CustomGlobalExecutor` pool with some lock which means only one job can run
/// at any given time
public final class LockCustomExecutor: SerialExecutor {
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    let lock = Lock()

    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        CustomGlobalExecutor.shared.pool.submit { [lock] in
            lock.whileLocked {
                job.runSynchronously(on: executor)
            }
        }
    }
}
