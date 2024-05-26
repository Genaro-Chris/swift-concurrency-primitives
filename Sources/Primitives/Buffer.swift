class Buffer<Element> {

    private var innerBuffer: ContiguousArray<Element>

    var count: Int {
        innerBuffer.count
    }

    var isEmpty: Bool {
        innerBuffer.isEmpty
    }

    init() {
        innerBuffer = ContiguousArray()
    }

    func enqueue(_ item: Element) {
        innerBuffer.append(item)
    }

    func dequeue() -> Element? {
        guard !innerBuffer.isEmpty else {
            return nil
        }
        return innerBuffer.removeFirst()
    }

    func clear() {
        innerBuffer.removeAll()
    }
}
