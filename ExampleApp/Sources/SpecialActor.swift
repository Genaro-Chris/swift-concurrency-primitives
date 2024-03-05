import Foundation

/// This actor uses the `SerialJobExecutor` as it's SerialExecutor
actor SpecialActor {

    private let executor = SerialJobExecutor()

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
