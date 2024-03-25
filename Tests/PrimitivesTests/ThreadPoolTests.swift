import XCTest

@testable import Primitives

final class ThreadPoolTests: XCTestCase {

    func test_pool_with_locked() {
        @Locked var total = 0
        do {
            let pool = WorkerPool(size: 4, waitType: .waitForAll)
            for index in 1 ... 10 {
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
            for index in 1 ... 10 {
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
        let handle = SingleThread(waitType: .cancelAll)
        for index in 1 ... 10 {
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
            let handle = SingleThread(waitType: .cancelAll)
            for index in 1 ... 10 {
                handle.submit {
                    $total.updateWhileLocked { $0 += index }
                }
            }
        }
        XCTAssertNotEqual(total, 55)
    }

    func test_worker_pool() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1 ... 10 {
            pool.submit {
                Thread.sleep(forTimeInterval: 1)
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_global_pool() {
        @Locked var total = 0
        for index in 1 ... 10 {
            WorkerPool.globalPool.submit {
                Thread.sleep(forTimeInterval: 1)
                $total.updateWhileLocked { $0 += index }
            }
        }
        WorkerPool.globalPool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_polling_pool() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1 ... 5 {
            pool.submit {
                Thread.sleep(forTimeInterval: 1)
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        for index in 6 ... 10 {
            pool.submit {
                Thread.sleep(forTimeInterval: 1)
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_thread_pool_with_sendable_closure() {
        @Locked var total = 0
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1 ... 10 {
            pool.async {
                Thread.sleep(forTimeInterval: 1)
                $total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total, 55)
    }
}
