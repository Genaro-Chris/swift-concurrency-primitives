import Foundation

/// This is a simple normal actor
actor NormalActor {

    private var innerCount = 0

    func increment(by value: Int) {
        innerCount += value
    }

    var count: Int {
        innerCount
    }
}
