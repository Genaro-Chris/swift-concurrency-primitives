import Foundation
@_spi(ThreadSync) import Primitives

final class NamedThread: Thread {

    let queue: UnboundedChannel<WorkItem>

    let latch: Latch

    let threadName: String

    let isBusy: Locked<Bool>

    override var name: String? {
        get { threadName } 
        set {}
    }

    var isBusyExecuting: Bool { isBusy.updateWhileLocked { $0 } }

    init(_ name: String, queue: UnboundedChannel<WorkItem>) {
        threadName = name
        isBusy = Locked(false)
        self.queue = queue
        latch = Latch(size: 1)
        super.init()
    }

    override func main() {
        while !isCancelled {
            for item in queue {
                isBusy.updateWhileLocked { $0 = true }
                item()
                isBusy.updateWhileLocked { $0 = false }
            }
        }
        latch.decrementAlone()
    }

    func join() {
        latch.waitForAll()
    }
}
