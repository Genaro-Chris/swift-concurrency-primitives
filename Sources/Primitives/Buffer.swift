import Foundation

@frozen @usableFromInline
struct Buffer<ElementType> {

    @usableFromInline var buffer: ContiguousArray<ElementType>

    var count: Int {
        buffer.count
    }

    @inlinable
    var isEmpty: Bool {
        buffer.isEmpty
    }

    @inlinable init() {
        buffer = ContiguousArray()
    }

    @inlinable
    mutating func enqueue(_ item: ElementType) {
        buffer.append(item)
    }

    @inlinable
    mutating func dequeue() -> ElementType? {
        guard !buffer.isEmpty else {
            return nil
        }
        return buffer.removeFirst()
    }

    mutating func clear() {
        buffer.removeAll()
    }
}
