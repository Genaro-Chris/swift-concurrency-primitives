import XCTest

@_spi(OtherChannels) @testable import Primitives

final class ChannelTests: XCTestCase {
    func test_one_shot_channel() {
        let random = Int.random(in: 1 ... 1000)
        let channel = OneShotChannel<Int>()
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 1)
            channel <- random
        }
        if let value = <-channel {
            XCTAssertEqual(random, value)
        }

    }

    func test_one_shot_channel_across_async() async {
        let random = Int.random(in: 1 ... 1000)
        let channel = OneShotChannel<Int>()
        Task.detached {
            channel <- random
        }
        if let value = <-channel {
            XCTAssertEqual(random, value)
        }
    }

    func test_zero_or_one_buffer_channel() {
        let channel = UnbufferedChannel<Int>()
        let handle = SingleThread(waitType: .waitForAll)
        handle.submit {
            let array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            channel.enumerated().forEach { (index, item) in XCTAssertEqual(item, array[index]) }
        }
        (0 ... 9).forEach {
            if channel.enqueue($0) {
                print("Sent \($0)")
            }
        }
        channel.close()
    }

    func test_bounded_channel() {
        let channel = BoundedChannel<Int>(size: 3)!
        let handle = SingleThread(waitType: .waitForAll)
        let pool = MultiThreadedPool(size: 4, waitType: .waitForAll)!
        handle.submit {
            let expected = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            var array = [Int]()
            for item in channel {
                print("Received \(item)")
                array.append(item)
            }
            XCTAssertEqual(expected, array.sorted())
        }
        @Locked var count = 0
        (0 ... 9).forEach { index in
            pool.submit { [index] in
                if channel.enqueue(index) {
                    print("Successfully sent \(index)")
                }
                $count.updateWhileLocked {
                    $0 += 1
                }
            }

        }
        while count != 10 {}
        print("count \(count)")
        channel.close()
    }

    func test_unbounded_channel() {
        let channel = UnboundedChannel<String>.init()
        let pool = MultiThreadedPool(size: 4, waitType: .waitForAll)!
        (0 ... 9).forEach { index in
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

    func test_channel_across_async() {
        let channel = UnbufferedChannel<Int>()
        Task { [channel] in
            channel <- 18
        }
        if let value = <-channel {
            XCTAssertEqual(value, 18)
        }
    }
}
