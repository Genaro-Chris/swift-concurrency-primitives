/// An array storage class for ``Channel`` types
final class ArrayStorage<Element> {

    var buffer: ContiguousArray<Element>

    let capacity: Int

    var bufferCount: Int

    var send: Bool

    var receive: Bool

    var closed: Bool

    init(capacity: Int) {
        self.capacity = capacity
        buffer = ContiguousArray()
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
