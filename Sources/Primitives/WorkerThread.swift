import Atomics
import Foundation

public typealias WorkItem = () -> Void

final class WorkerThread: Thread {

    typealias TaskQueue = Queue<WorkItem>

    private let threadName: String

    private let queue: TaskQueue

    private let isBusy: ManagedAtomic<Bool>

    private let condition: Condition

    private let mutex: Mutex

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

    init(_ name: String) {
        threadName = name
        queue = Queue()
        isBusy = ManagedAtomic(false)
        mutex = Mutex()
        condition = Condition()
        super.init()
    }

    func submit(_ body: @escaping WorkItem) {
        mutex.whileLocked {
            queue <- body
            condition.signal()
        }
    }

    fileprivate func dequeue() -> WorkItem? {
        return mutex.whileLocked {
            condition.wait(mutex: mutex, condition: !queue.isEmpty)
            guard !queue.isEmpty else { return nil }
            return queue.dequeue()
        }
    }

    override func main() {
        while !isCancelled {
            if let work = dequeue() {
                isBusy.store(true, ordering: .relaxed)
                work()
                isBusy.store(false, ordering: .relaxed)
            }
        }
    }
}
