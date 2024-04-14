import Atomics
import Foundation

public typealias WorkItem = () -> Void

public typealias SendableWorkItem = @Sendable () -> Void

final class WorkerThread: Thread {

    let latch: Latch

    let queue: UnboundedChannel<() -> Void>

    let threadName: String

    var isBusyExecuting: Bool {
        isBusy.load(ordering: .relaxed)
    }

    var isEmpty: Bool {
        queue.isEmpty
    }

    override var name: String? {
        get { threadName }
        set {}
    }

    let isBusy: ManagedAtomic<Bool>

    func submit(_ body: @escaping () -> Void) {
        queue <- body
    }

    init(_ name: String) {
        latch = Latch(size: 1)
        queue = UnboundedChannel()
        isBusy = ManagedAtomic(false)
        threadName = name
        super.init()
    }

    override func main() {
        while !self.isCancelled {
            for operation in queue {
                isBusy.store(true, ordering: .relaxed)
                operation()
                isBusy.store(false, ordering: .relaxed)
            }
            isBusy.store(false, ordering: .relaxed)
        }
        latch.decrementAndWait()
    }

    func clear() {
        queue.clear()
    }

    override func cancel() {
        queue.close()
        queue.clear()
        super.cancel()
    }

    func join() {
        latch.waitForAll()
    }

}
