import Foundation

final class TaskChannel {

    let mutex: Mutex

    let condition: Condition

    var buffer: ContiguousArray<WorkItem>

    var closed: Bool

    var isEmpty: Bool {
        return mutex.whileLocked {
            return buffer.isEmpty
        }
    }

    init() {
        buffer = ContiguousArray()
        mutex = Mutex()
        condition = Condition()
        closed = false
    }

    func enqueue(_ item: @escaping WorkItem) {
        mutex.whileLockedVoid {
            buffer.append(item)
            condition.signal()
        }
    }

    func dequeue() -> WorkItem? {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: !buffer.isEmpty || closed)
            guard !buffer.isEmpty else { return nil }
            return buffer.removeFirst()
        }
    }

    func clear() {
        mutex.whileLockedVoid {
            buffer.removeAll()
        }
    }

    func end() {
        mutex.whileLockedVoid {
            closed = true
            buffer.removeAll()
            condition.signal()
        }
    }
}
