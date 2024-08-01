import Foundation
@preconcurrency import Primitives

/// This enqueues job onto a `WorkerThread` which means that the jobs executes in the order in which they were
/// enqueued thus avoiding data race
final class SerialJobExecutor: SerialExecutor {

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    init() {}

    private let threadHandle = WorkerThread()

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        threadHandle.submit {
            job.runSynchronously(on: executor)
        }
    }

}
