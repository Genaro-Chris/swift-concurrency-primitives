@_spi(ThreadSync) @testable import Primitives
import XCTest

final class PrimitivesTests: XCTestCase {

    func test_Queue() {
        let queue = Queue<String>()
        DispatchQueue.concurrentPerform(iterations: 10) { [queue] index in
            queue.enqueue(item: "\(index)")
        }
        let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { String($0) }
        var results: [String] = []
        while let result = queue.dequeue() {
            results.append(result)
        }
        XCTAssertEqual(results.sorted(), expected)
        XCTAssertEqual(results.count, 10)
    }

    func test_Latch() {
        var queue = 0
        let latch = Latch(size: 10)
        let lock = Lock()
        for value in 1...10 {
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

    func test_Latch_DecrementAlone() {
        var queue = 0
        let latch = Latch(size: 11)
        let lock = Lock()
        for value in 1...10 {
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

    func test_Barrier() {
        let barrier = Barrier(size: 2)
        let semaphore = LockSemaphore(size: 10)
        let lock = Lock()
        var total = 0
        XCTAssertNotNil(barrier)
        (1...10).forEach { index in
            Thread { [semaphore] in
                defer {
                    semaphore.notify()
                }
                lock.whileLocked {
                    total += 1
                }
                print("Wait blocker \(index)")
                barrier.arriveAndWait()
                print("After blocker \(index)")
            }.start()
        }
        semaphore.waitForAll()
        XCTAssertEqual(total, 10)
    }

    func test_Barrier_DecrementAlone() {
        let barrier = Barrier(size: 5)
        let lock = Lock()
        var total = 0
        let waitGroup = WaitGroup()
        (1...9).forEach { index in
            waitGroup.enter()
            Thread { [waitGroup] in
                lock.whileLocked {
                    total += 1
                }
                print("Wait blocker \(index)")
                barrier.arriveAndWait()
                print("After blocker \(index)")
                waitGroup.done()
            }.start()
        }
        lock.whileLocked {
            total += 1
        }
        print("Wait blocker \(10)")
        barrier.arriveAlone()
        print("After blocker \(10)")
        waitGroup.waitForAll()
        XCTAssertEqual(total, 10)
    }

    func test_Condition_Signal() {
        let condition = Condition()
        let lock = Mutex()
        var total = 0
        let threadHanddles = (1...5).map { index in
            Thread {
                lock.whileLocked {
                    total += index
                    condition.wait(mutex: lock)
                }
            }
        }
        threadHanddles.forEach { $0.start() }

        Thread.sleep(forTimeInterval: 1)

        (1...5).forEach { _ in condition.signal() }

        threadHanddles.forEach { $0.cancel() }
        lock.whileLocked {
            XCTAssertEqual(total, 15)
        }
    }

    func test_Condition_Broadcast() {
        let condition = Condition()
        let lock = Mutex()
        var total = 0
        let threadHanddles = (1...5).map { index in
            Thread {
                lock.whileLocked {
                    total += index
                    condition.wait(mutex: lock)
                }
            }
        }
        threadHanddles.forEach { $0.start() }

        Thread.sleep(forTimeInterval: 1)

        condition.broadcast()

        threadHanddles.forEach { $0.cancel() }
        lock.whileLocked {
            XCTAssertEqual(total, 15)
        }
    }

    func test_Condition_Wait() {
        let condition = Condition()
        let lock = Mutex()
        let total = 0
        let threadHandles = (1...5).map { index in
            Thread {
                defer {
                    print("Thread \(index) done")
                }
                lock.whileLocked {
                    _ = condition.wait(mutex: lock, timeout: .milliseconds(300))
                    if index % 5 == 0 {
                        condition.signal()
                    }
                }
            }
        }

        threadHandles.forEach { $0.start() }

        lock.whileLocked {
            _ = condition.wait(mutex: lock, timeout: .milliseconds(1200))
        }

        threadHandles.forEach { $0.cancel() }
        lock.whileLocked {
            XCTAssertEqual(total, 0)
        }
    }
}
