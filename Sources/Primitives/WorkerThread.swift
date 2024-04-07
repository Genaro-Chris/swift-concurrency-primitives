import Atomics
import Foundation

public typealias WorkItem = () -> Void

public typealias SendableWorkItem = @Sendable () -> Void

final class WorkerThread: Thread {

    private let latch: Latch

    private let queue: UnboundedChannel<() -> Void>

    private let threadName: String

    var isBusyExecuting: Bool {
        isBusy.updateWhileLocked { $0 }
    }

    var isEmpty: Bool {
        queue.isEmpty
    }

    override var name: String? {
        get { threadName }
        set {}
    }

    private let isBusy: Locked<Bool>

    func submit(_ body: @escaping () -> Void) {
        queue <- body
    }

    init(_ name: String) {
        latch = Latch(size: 1)
        queue = UnboundedChannel()
        isBusy = Locked(false)
        threadName = name
        super.init()
    }

    override func main() {
        while !self.isCancelled {
            for work in queue {
                isBusy.updateWhileLocked { $0 = true }
                work()
            }
            isBusy.updateWhileLocked { $0 = false }
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
