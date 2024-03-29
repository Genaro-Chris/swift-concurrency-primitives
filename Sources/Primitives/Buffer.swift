import Foundation

@_fixed_layout @usableFromInline
class Buffer<ElementType> {

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
    func enqueue(_ item: ElementType) {
        buffer.append(item)
    }

    @inlinable
    func dequeue() -> ElementType? {
        guard !buffer.isEmpty else {
            return nil
        }
        return buffer.removeFirst()
    }

    func clear() {
        buffer.removeAll()
    }
}
