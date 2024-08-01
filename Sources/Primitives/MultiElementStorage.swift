/// A multi item storage class for ``Channel`` types
final class MultiElementStorage<Element> {

    var buffer: ContiguousArray<Element>

    let capacity: Int

    var bufferCount: Int

    var send: Bool

    var receive: Bool

    var closed: Bool

    init(capacity: Int = 1) {
        self.capacity = capacity
        buffer = ContiguousArray()
        buffer.reserveCapacity(capacity)
        send = true
        receive = false
        bufferCount = 0
        closed = false
    }

    var count: Int {
        buffer.count
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }

    func enqueue(_ item: Element) {
        buffer.append(item)
    }

    func dequeue() -> Element? {
        guard !buffer.isEmpty else {
            return nil
        }
        return buffer.removeFirst()
    }

    func clear() {
        buffer.removeAll()
    }
}