@_spi(OtherChannels) @testable import Primitives
import XCTest

final class ChannelTests: XCTestCase {
    func test_one_shot_channel() {
        let random = Int.random(in: 1...1000)
        let channel = OneShotChannel<Int>()
        DispatchQueue.global().async {
            channel <- random
        }
        if let value = <-channel {
            XCTAssertEqual(random, value)
        }

    }

    func test_zero_or_one_buffer_channel() {
        let channel = UnbufferedChannel<Int>()
        let handle = WorkerThread(waitType: .waitForAll)
        handle.submit {
            let array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            channel.enumerated().forEach { (index, item) in XCTAssertEqual(item, array[index]) }
        }
        (0...9).forEach {
            if channel.enqueue($0) {
                print("Sent \($0)")
            }
        }
        channel.close()
    }

    func test_bounded_channel() {
        let channel = BoundedChannel<Int>(size: 3)
        let handle = WorkerThread(waitType: .waitForAll)
        let pool = WorkerPool(size: 4, waitType: .waitForAll)
        handle.submit {
            let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            let array = channel.map { item in
                return item
            }
            XCTAssertEqual(expected, array.sorted())

        }
        let waitGroup = WaitGroup()
        (0...9).forEach { index in
            waitGroup.enter()
            pool.submit { [index] in
                defer {
                    waitGroup.done()
                    print("Done with \(index)")
                }
                if channel.enqueue(index) {
                    print("Successfully sent \(index)")
                }
            }
        }
        waitGroup.waitForAll()
        channel.close()

    }

    func test_unbounded_channel() {
        let channel = UnboundedChannel<String>.init()
        let pool = WorkerPool(size: 4, waitType: .waitForAll)
        (0...9).forEach { index in
            pool.submit { [channel] in
                channel <- "\(index)"
            }
        }
        pool.pollAll()
        channel.close()
        XCTAssertEqual(channel.length, 10)
        let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { String($0) }
        let result = channel.map { item in
            return item
        }.sorted()
        XCTAssertEqual(result, expected)
    }

}
