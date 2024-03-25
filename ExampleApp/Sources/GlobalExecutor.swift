import Foundation
@preconcurrency import Primitives

/// The class that replaces the global concurrency by enqueueing jobs onto some `ThreadPool` type
public final class CustomGlobalExecutor: SerialExecutor {
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    let pool: ThreadPool

    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        pool.submit {
            job.runSynchronously(on: executor)
        }
    }

    /// Initializes this type
    /// - Parameter pool: any `ThreadPool` conforming type where the enqueued job will run on
    init(_ pool: ThreadPool) {
        self.pool = pool
    }

    #if canImport(Glibc) || canImport(Darwin)
        static let shared = CustomGlobalExecutor(WorkerPool.globalPool)
    #else
        static let shared = CustomGlobalExecutor(SimpleThreadPool.globalPool)
    #endif
}

/// Does what the name implies
func replacesSwiftGlobalConcurrencyHook() {
    // This ensures that we only replace the global concurrency hook only once per process
    Once.runOnce {
        typealias EnqueueOriginal = @convention(thin) (UnownedJob) -> Void

        typealias EnqueueHook = @convention(thin) (UnownedJob, EnqueueOriginal) -> Void

        let handle = dlopen(nil, RTLD_LAZY)
        let enqueueGlobalHookPtr = dlsym(handle, "swift_task_enqueueGlobal_hook")!
            .assumingMemoryBound(to: EnqueueHook.self)

        enqueueGlobalHookPtr.pointee = { opaqueJob, _ in
            CustomGlobalExecutor.shared.enqueue(opaqueJob)
        }
    }
}
