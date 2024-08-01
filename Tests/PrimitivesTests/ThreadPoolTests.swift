import XCTest

@testable import Primitives

final class ThreadPoolTests: XCTestCase {

    func test_WorkerPool_With_Locked() {
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

    func test_Cancelling_WorkerPool_With_Locked() {
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

    func test_WorkerThread() {
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

    func test_Cancelling_WorkerThread() {
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

    func test_WorkerPool() {
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

    func test_Global_WorkerPool() {
        @Locked var total = 0
        for index in 1...10 {
            WorkerPool.globalPool.submit {
                $total.updateWhileLocked { $0 += index }
            }
        }
        WorkerPool.globalPool.pollAll()
        XCTAssertEqual(total, 55)
    }

    func test_Polling_WorkerPool() {
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

    func test_Cancel_WorkerPool() {
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

    func test_WorkerPool_With_Sendable_Closure() {
        let total = Locked(initialValue: 0)
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        for index in 1...10 {
            pool.async {
                total.updateWhileLocked { $0 += index }
            }
        }
        pool.pollAll()
        XCTAssertEqual(total.wrappedValue, 55)
    }
}
