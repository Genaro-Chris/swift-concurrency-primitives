import Foundation
@_spi(ThreadSync) import Primitives

final class UnnamedThread: Thread {

    let queue: UnboundedChannel<TaskItem>

    let latch: Latch

    let threadName: String

    let isBusy: Locked<Bool>

    override var name: String? {
        get { threadName } 
        set {}
    }

    var isBusyExecuting: Bool { isBusy.updateWhileLocked { $0 } }

    init(_ name: String) {
        threadName = name
        isBusy = Locked(false)
        queue = UnboundedChannel()
        latch = Latch(size: 1)
        super.init()
    }

    override func main() {
        while true {
            for item in queue where !isCancelled {
                isBusy.updateWhileLocked { $0 = true }
                item()
                isBusy.updateWhileLocked { $0 = false }
            }
        }
        latch.decrementAlone()
    }

    func submit(_ body: @escaping TaskItem) {
        queue <- body
    }

    func clear() {
        queue.clear()
    }

    func join() {
        latch.waitForAll()
    }
}
