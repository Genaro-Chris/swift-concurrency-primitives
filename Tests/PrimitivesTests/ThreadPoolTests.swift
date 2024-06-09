import XCTest

@testable import Primitives

final class ThreadPoolTests: XCTestCase {

    func test_pool_with_locked() {
        @Locked var total = 0
        do {
            let pool = WorkerPool(size: 4, waitType: .waitForAll)
            for index in 1...10 {
                pool.submit {
                    $total.updateWhileLocked { $0 += index }
                }
            }
        }
        XCTAssertEqual(total, 55)
    }

    func test_cancelling_pool_with_locked() {
        @Locked var total = 0
        do {
            let pool = WorkerPool(size: 3, waitType: .cancelAll)
            for index in 1...10 {
                pool.submit {
                    Thread.sleep(forTimeInterval: 0.1)
                    $total.updateWhileLocked { $0 += index }
                }
            }
        }
        XCTAssertNotEqual(total, 55)
    }

    func test_singlethread() {
        @Locked var total = 0
        let handle = WorkerThread(waitType: .cancelAll)
        for index in 1...10 {
            handle.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        handle.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_cancelling_singlethread() {
        @Locked var total = 0
        do {
            let handle = WorkerThread(waitType: .cancelAll)
            for index in 1...10 {
                handle.submit {
                    Thread.sleep(forTimeInterval: 0.7)
                    $total.updateWhileLocked { $0 += index }
                }
            }
        }
        XCTAssertNotEqual(total, 55)
    }

    func test_worker_pool() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1...10 {
            pool.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_global_pool() {
        @Locked var total = 0
        for index in 1...10 {
            WorkerPool.globalPool.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        WorkerPool.globalPool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_polling_pool() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1...5 {
            pool.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        for index in 6...10 {
            pool.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_cancel_pool() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1...10 {
            pool.submit {
                Thread.sleep(forTimeInterval: 0.5)
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.cancel()
        XCTAssertNotEqual(total, 55)
    }

    func test_thread_pool_with_sendable_closure() {
        let total = LockedBox(0)
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1...10 {
            pool.async {
                total.interact { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total.value, 55)
    }
}

class LockedBox<T>: @unchecked Sendable {
    @Locked var value: T
    init(_ value: T) {
        self._value = Locked(value)
    }

    func interact<V>(_ with: (inout T) throws -> V) rethrows -> V {
        return try $value.updateWhileLocked(with)
    }
}
