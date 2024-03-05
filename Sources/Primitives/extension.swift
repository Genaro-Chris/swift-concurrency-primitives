import Foundation

extension Thread {

    @inlinable
    static func yield() {
        Thread.sleep(forTimeInterval: 0.0000000000000000001)
    }
}
