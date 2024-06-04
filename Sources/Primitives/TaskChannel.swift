final class TaskChannel {

    let mutex: Mutex

    let condition: Condition

    var buffer: ContiguousArray<WorkItem>

    var isEmpty: Bool {
        return mutex.whileLocked {
            return buffer.isEmpty
        }
    }

    init(_ count: Int = 1) {
        buffer = ContiguousArray()
        buffer.reserveCapacity(count)
        mutex = Mutex()
        condition = Condition()
    }

    func enqueue(_ item: @escaping WorkItem) {
        mutex.whileLocked {
            buffer.append(item)
            condition.signal()
        }
    }

    func dequeue() -> WorkItem? {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: !buffer.isEmpty)
            guard !buffer.isEmpty else { return nil }
            return buffer.removeFirst()
        }
    }

    func clear() {
        mutex.whileLocked {
            buffer.removeAll()
        }
    }

    func end() {
        mutex.whileLocked {
            buffer.removeAll()
            condition.broadcast()
        }
    }
}
