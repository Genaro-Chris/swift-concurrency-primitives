import Atomics
import Foundation

final class WorkerThread: Thread {

    typealias TaskQueue = Queue<() -> Void>

    private let latch: Latch

    private let queue: TaskQueue

    private let threadName: String

    private let isBusy: UnsafeAtomic<Bool>

    private let block: () -> Void

    override var name: String? {
        get { threadName }
        set {}
    }

    public var isBusyExecuting: Bool {
        isBusy.load(ordering: .relaxed)
    }

    var isEmpty: Bool {
        queue.isEmpty
    }

    func submit(_ body: @escaping () -> Void) {
        queue <- body
    }

    init(_ name: String = Thread.current.name ?? "Thread") {
        latch = Latch(size: 1)!
        queue = TaskQueue()
        threadName = name
        isBusy = UnsafeAtomic.create(false)
        block = { [queue, isBusy] in
            repeat {
                if let work = <-queue {
                    isBusy.store(true, ordering: .relaxed)
                    work()
                    isBusy.store(false, ordering: .relaxed)
                } else {
                    Thread.sleep(forTimeInterval: 0.0010)
                }
            } while !Thread.current.isCancelled
        }
        super.init()
    }

    override func main() {
        block()
        latch.decrementAlone()
    }

    func join() {
        latch.waitForAll()
    }

    deinit {
        isBusy.destroy()
    }

}
