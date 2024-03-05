import Foundation

/// This actor uses the `LockCustomExecutor` as it's SerialExecutor
actor LockActor {

    private let executor = LockCustomExecutor()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: executor)
    }

    private var innerCount = 0

    func increment(by value: Int) {
        innerCount += value
    }

    var count: Int {
        innerCount
    }
}
