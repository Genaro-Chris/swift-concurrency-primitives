@usableFromInline
class Buffer<Element> {

    @usableFromInline var innerBuffer: ContiguousArray<Element>

    @usableFromInline var buffer: ContiguousArray<Element> {
        _read { yield innerBuffer }
        _modify { yield &innerBuffer }
    }

    var count: Int {
        buffer.count
    }

    @inlinable
    var isEmpty: Bool {
        buffer.isEmpty
    }

    @inlinable init() {
        innerBuffer = ContiguousArray()
    }

    @inlinable
    func enqueue(_ item: Element) {
        buffer.append(item)
    }

    @inlinable
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
