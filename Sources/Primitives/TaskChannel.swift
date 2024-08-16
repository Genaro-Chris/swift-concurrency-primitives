import Foundation

struct TaskChannel {

    let bufferLock: ConditionalLockBuffer<Storage<() -> Void>>

    var isEmpty: Bool {
        return bufferLock.interactWhileLocked { buffer, _ in
            buffer.isEmpty
        }
    }

    init() {
        bufferLock = ConditionalLockBuffer.create(value: Storage())
    }

    func enqueue(_ item: @escaping () -> Void) {
        bufferLock.interactWhileLocked { buffer, conditionLock in
            buffer.enqueue(item)
            if buffer.count == 1 {
                conditionLock.signal()
            }
        }
    }

    func dequeue() -> (() -> Void)? {
        bufferLock.interactWhileLocked { buffer, conditionLock in
            conditionLock.wait(for: !buffer.isEmpty || buffer.closed)
            return buffer.dequeue()
        }
    }

    func clear() {
        bufferLock.interactWhileLocked { buffer, _ in
            buffer.clear()
        }
    }

    func end() {
        bufferLock.interactWhileLocked { buffer, conditionLock in
            buffer.closed = true
            buffer.clear()
            conditionLock.signal()
        }
    }
}
