class Buffer<Element> {

    private var innerBuffer: ContiguousArray<Element>

    var buffer: ContiguousArray<Element> {
        _read { yield innerBuffer }
        _modify { yield &innerBuffer }
    }

    var count: Int {
        buffer.count
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }

    init() {
        innerBuffer = ContiguousArray()
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
