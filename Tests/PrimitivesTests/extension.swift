import Foundation
import Primitives

extension Queue: Sequence, IteratorProtocol {
    public func next() -> Element? {
        dequeue()
    }
}
