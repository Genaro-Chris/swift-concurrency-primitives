import XCTest

@_spi(ThreadSync) @testable import Primitives

final class PrimitivesTests: XCTestCase {

    func test_queue() {
        let queue = Queue<String>()
        (0 ... 9).forEach { [queue] index in queue.enqueue("\(index)") }
        let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { String($0) }
        let result: [String] = queue.map { $0 }
        XCTAssertEqual(result, expected)
        XCTAssertEqual(result.count, 10)
    }

    func test_queue_over_async() async {
        let queue = Queue<String>()
            await withTaskGroup(of: Void.self) { group in
                (0 ... 9).forEach { index in
                    group.addTask {
                        queue.enqueue("\(index)")
                    }
                }
            }
            let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { String($0) }
            let result = queue.map { $0 }.sorted()
            XCTAssertEqual(result, expected)
            XCTAssertEqual(result.count, 10)
    }

    func test_latch() {
        var queue = 0
        let latch = Latch(size: 10)!
        let lock = Lock()
        for value in 1 ... 10 {
            Thread {
                lock.whileLocked {
                    queue += value
                }
                latch.decrementAndWait()
            }.start()
        }
        latch.waitForAll()
        XCTAssertEqual(queue, 55)
    }

    func test_latch_decrement_alone() {
        var queue = 0
        let latch = Latch(size: 11)!
        let lock = Lock()
        for value in 1 ... 10 {
            Thread {
                lock.whileLocked {
                    queue += value
                }
                latch.decrementAndWait()
            }.start()
        }
        latch.decrementAlone()
        latch.waitForAll()
        XCTAssertEqual(queue, 55)
    }

    func test_barrier() {
        let barrier = Barrier(size: 2)
        let notifier = Notifier(size: 10)
        let lock = Lock()
        var total = 0
        XCTAssertNotNil(barrier)
        (1 ... 10).forEach { index in
            Thread { [notifier] in
                defer {
                    notifier?.notify()
                }
                lock.whileLocked {
                    total += 1
                }
                print("Wait blocker \(index)")
                barrier?.arriveAndWait()
                print("After blocker \(index)")
            }.start()
        }
        notifier?.waitForAll()
        XCTAssertEqual(total, 10)
    }

    func test_barrier_decrement_alone() {
        let barrier = Barrier(size: 5)
        let lock = Lock()
        var total = 0
        let waitGroup = WaitGroup()
        (1 ... 9).forEach { index in
            waitGroup.enter()
            Thread { [waitGroup] in
                lock.whileLocked {
                    total += 1
                }
                print("Wait blocker \(index)")
                barrier?.arriveAndWait()
                print("After blocker \(index)")
                waitGroup.done()
            }.start()
        }
        lock.whileLocked {
            total += 1
        }
        print("Wait blocker \(10)")
        barrier?.arriveAlone()
        print("After blocker \(10)")
        waitGroup.waitForAll()
        XCTAssertEqual(total, 10)
    }
}
