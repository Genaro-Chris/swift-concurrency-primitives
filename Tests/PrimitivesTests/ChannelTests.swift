@_spi(OtherChannels) @testable import Primitives
import XCTest

final class ChannelTests: XCTestCase {
    func test_OneShotChannel() {
        let random = Int.random(in: 1...1000)
        let channel = OneShotChannel<Int>()
        let semaphore = LockSemaphore(size: 5)
        for _ in 1...5 {
            DispatchQueue.global().async {
                channel <- random
                semaphore.notify()
            }
        }
        semaphore.waitForAll()
        var count = 0
        for item in channel {
            defer { count += 1 }
            XCTAssertEqual(random, item)
        }
        XCTAssertEqual(count, 1)
    }

    func test_UnbufferedChannel() {
        let channel = UnbufferedChannel<Int>()
        let handle = WorkerThread(waitType: .waitForAll)
        handle.submit {
            let array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            channel.enumerated().forEach { (index, item) in
                print("Got \(item)")
                XCTAssertEqual(item, array[index])
            }
        }
        (0...9).forEach {
            if channel.enqueue(item: $0) {
                print("Sent \($0)")
            }
        }
        channel.close()
    }

    func test_BoundedChannel() {
        let channel = BoundedChannel<Int>(size: 3)
        let handle = WorkerThread(waitType: .cancelAll)
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        handle.submit {
            let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            let array = channel.map { item in
                return item
            }
            XCTAssertEqual(expected, array.sorted())

        }
        (0...9).forEach { index in
            pool.submit { [index] in
                if channel.enqueue(item: index) {
                    print("Successfully sent \(index)")
                }
            }
        }
        pool.pollAll()
        channel.close()
    }

    func test_UnboundedChannel() {
        let channel = UnboundedChannel<String>()
        let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { String($0) }
        let pool = WorkerPool(size: 4, waitType: .cancelAll)
        (0...9).forEach { index in
            pool.submit { [channel] in
                channel <- "\(index)"
            }
        }
        DispatchQueue.global().async {
            pool.pollAll()
            channel.close()
        }
        let results: [String] = channel.map { $0 }.sorted()
        XCTAssertEqual(results.count, 10)
        XCTAssertEqual(results, expected)
    }

}
