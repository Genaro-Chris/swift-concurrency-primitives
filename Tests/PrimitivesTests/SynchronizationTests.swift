import XCTest

@testable import Primitives

final class SynchronizationTests: XCTestCase {

    func test_Once() {
        var total = 0
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            Once.runOnce {
                total += 1
            }
        }
        XCTAssertEqual(total, 1)
    }

    func test_OnceState() {
        var total = 0
        let once = OnceState()
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            once.runOnce {
                total += 1
            }
        }
        XCTAssertEqual(total, 1)
    }

    func test_Lock() {
        var total = 0
        let lock = Lock()
        DispatchQueue.concurrentPerform(iterations: 11) { index in
            lock.whileLocked {
                total += index
            }
        }
        XCTAssertEqual(total, 55)
    }

    func test_Locked() {
        struct Student {
            var age: Int = 0
            var scores: [Int] = []
        }
        let student = Locked(initialValue: Student())
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            student.updateWhileLocked { student in
                student.scores.append(index)
                if index == 9 {
                    student.age = 18
                }
            }
        }
        XCTAssertEqual(student.age, 18)
    }

    func test_LockedWrapper() {
        struct Student {
            var age: Int = 0
            var scores: [Int] = []
        }
        @Locked var student = Student()
        DispatchQueue.concurrentPerform(iterations: 11) { index in
            $student.updateWhileLocked { student in
                student.scores.append(index)
                if index == 9 {
                    student.age = 18
                }
            }
        }
        XCTAssertEqual(student.age, 18)
    }

    func test_LockSemaphore() {
        struct Student {
            var age: Int = 0
            var scores: [Int] = []
        }
        @Locked var student = Student()
        let semaphore = LockSemaphore(size: 10)
        (1...10).forEach { index in
            DispatchQueue.global().async {
                defer { semaphore.notify() }
                $student.updateWhileLocked { student in
                    student.scores.append(index)
                    if index == 9 {
                        student.age = 18
                    }
                }
            }
        }
        semaphore.waitForAll()
        XCTAssertEqual(student.age, 18)
    }

    func test_WaitGroup() {
        let lock = Lock()
        var total = 0
        let waitGroup = WaitGroup()
        (1...10).forEach { index in
            waitGroup.enter()
            Thread { [waitGroup] in
                lock.whileLocked {
                    total += index
                }
                waitGroup.done()
            }.start()
        }
        waitGroup.waitForAll()
        XCTAssertEqual(total, 55)
    }
}
