struct Storage<Element> {

    var buffer: ContiguousArray<Element>

    var closed: Bool

    init() {
        buffer = ContiguousArray()
        closed = false
    }

    var count: Int {
        buffer.count
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }

    mutating func enqueue(_ item: Element) {
        buffer.append(item)
    }

    mutating func dequeue() -> Element? {
        guard !buffer.isEmpty else {
            return nil
        }
        return buffer.removeFirst()
    }

    mutating func clear() {
        buffer.removeAll()
    }
}
