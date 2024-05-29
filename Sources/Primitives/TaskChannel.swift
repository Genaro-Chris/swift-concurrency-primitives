final class TaskChannel {

    let mutex: Mutex

    let condition: Condition

    var buffer: ContiguousArray<QueueOperations>

    init() {
        buffer = ContiguousArray()
        mutex = Mutex()
        condition = Condition()
    }

    func enqueue(_ item: QueueOperations) {
        mutex.whileLocked {
            buffer.append(item)
            condition.signal()
        }
    }

    func dequeue() -> WorkItem? {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: !buffer.isEmpty)
            guard !buffer.isEmpty else { return nil }
            switch buffer.removeFirst() {
            case .execute(let block): return block

            case .wait(let barrier): return { barrier.arriveAndWait() }
            }
        }
    }

    func clear() {
        mutex.whileLocked {
            buffer.removeAll()
        }
    }

    func end() {
        condition.broadcast()
    }
}
